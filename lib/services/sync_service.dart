import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bank_account.dart';
import '../models/custom_category.dart';
import '../models/custom_rule.dart';
import '../models/transaction.dart';
import 'database_service.dart';

class SyncResult {
  final String message;
  const SyncResult(this.message);
}

class SyncService {
  static final _db = DatabaseService();
  static final _fs = FirebaseFirestore.instance;

  static String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    return uid;
  }

  static DocumentReference<Map<String, dynamic>> get _userDoc =>
      _fs.collection('users').doc(_uid);

  // ── Push — local → cloud ──────────────────────────────────────────────────

  static Future<SyncResult> push() async {
    final uid = _uid;
    final userDoc = _fs.collection('users').doc(uid);

    // Read current cloud state first so we merge rather than overwrite.
    // Key structure: monthKey → rawMessage → transaction map.
    final cloudSnap = await userDoc.collection('months').get();
    final merged = <String, Map<String, Map<String, dynamic>>>{};
    for (final doc in cloudSnap.docs) {
      final list =
          (doc.data()['transactions'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
      merged[doc.id] = {
        for (final t in list)
          if (t['rawMessage'] != null) t['rawMessage'] as String: t,
      };
    }

    // Layer local transactions on top (local wins on conflict).
    // Manual transactions (rawMessage == null) are local-only — not synced.
    final txns = await _db.queryAll();
    for (final t in txns) {
      final raw = t.rawMessage;
      if (raw == null) continue;
      final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      (merged[key] ??= {})[raw] = _toCloud(t);
    }

    // Strip any cloud transactions that this device has soft-deleted.
    // Without this, deleted transactions would survive in the cloud copy and
    // re-appear on other devices after they pull.
    final localDeleted = await _db.deletedRawMessages();
    for (final monthMap in merged.values) {
      monthMap.removeWhere((raw, _) => localDeleted.contains(raw));
    }
    merged.removeWhere((_, monthMap) => monthMap.isEmpty);

    // Sync full deleted transaction data so other devices get them in their
    // deleted list (Option A: deleted-months collection mirrors months structure).
    final cloudDeletedSnap = await userDoc.collection('deleted-months').get();
    final mergedDeleted = <String, Map<String, Map<String, dynamic>>>{};
    for (final doc in cloudDeletedSnap.docs) {
      final list =
          (doc.data()['transactions'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
      mergedDeleted[doc.id] = {
        for (final t in list)
          if (t['rawMessage'] != null) t['rawMessage'] as String: t,
      };
    }
    final localDeletedTxns = await _db.getDeletedTransactions();
    for (final t in localDeletedTxns) {
      final raw = t.rawMessage;
      if (raw == null) continue;
      final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      (mergedDeleted[key] ??= {})[raw] = _toCloud(t);
    }

    final accounts = await _db.loadAccounts();
    final localRules = await _db.loadRules();
    final categories = await _db.loadCustomCategories();

    // Firestore batch (max 500 ops — well within limit for personal use)
    final batch = _fs.batch();

    for (final entry in merged.entries) {
      batch.set(
        userDoc.collection('months').doc(entry.key),
        {'transactions': entry.value.values.toList()},
      );
    }

    for (final entry in mergedDeleted.entries) {
      batch.set(
        userDoc.collection('deleted-months').doc(entry.key),
        {'transactions': entry.value.values.toList()},
      );
    }

    batch.set(userDoc.collection('data').doc('accounts'),
        {'items': accounts.map((a) => a.toMap()).toList()});

    // Merge rules by id: start with cloud rules, local wins on conflict.
    final rulesSnap = await userDoc.collection('data').doc('rules').get();
    final cloudRules = <String, Map<String, dynamic>>{};
    if (rulesSnap.exists) {
      for (final r
          in (rulesSnap.data()!['items'] as List).cast<Map<String, dynamic>>()) {
        cloudRules[r['id'] as String] = r;
      }
    }
    for (final r in localRules) {
      cloudRules[r.id] = r.toMap();
    }
    batch.set(userDoc.collection('data').doc('rules'),
        {'items': cloudRules.values.toList()});
    batch.set(userDoc.collection('data').doc('categories'),
        {'items': categories.map((c) => c.toMap()).toList()});

    // Merge deletions: union of cloud deleted rawMessages + local deleted rawMessages.
    // This list only ever grows — deletions are permanent across devices.
    final deletionsSnap =
        await userDoc.collection('data').doc('deletions').get();
    final cloudDeleted = <String>{};
    if (deletionsSnap.exists) {
      cloudDeleted.addAll(
          ((deletionsSnap.data()!['rawMessages'] as List?) ?? [])
              .cast<String>());
    }
    batch.set(userDoc.collection('data').doc('deletions'),
        {'rawMessages': cloudDeleted.union(localDeleted).toList()});
    batch.set(
      userDoc,
      {'lastSyncedAt': FieldValue.serverTimestamp(), 'uid': uid},
      SetOptions(merge: true),
    );

    await batch.commit();

    final totalTxns = merged.values.fold(0, (acc, m) => acc + m.length);
    return SyncResult(
        'Pushed. Cloud now has $totalTxns transactions across ${merged.length} months.');
  }

  // ── Pull — cloud → local ──────────────────────────────────────────────────

  static Future<SyncResult> pull() async {
    final userDoc = _userDoc;

    final monthsSnap = await userDoc.collection('months').get();
    final deletedMonthsSnap = await userDoc.collection('deleted-months').get();
    final dataSnap = await userDoc.collection('data').get();

    // Parse all cloud active transactions
    final cloudTxns = <Transaction>[];
    for (final doc in monthsSnap.docs) {
      final list =
          (doc.data()['transactions'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
      cloudTxns.addAll(list.map(_fromCloud));
    }

    // Parse all cloud deleted transactions
    final cloudDeletedTxns = <Transaction>[];
    for (final doc in deletedMonthsSnap.docs) {
      final list =
          (doc.data()['transactions'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
      cloudDeletedTxns.addAll(list.map(_fromCloud));
    }

    // Helper to find a data doc
    Map<String, dynamic>? dataDoc(String id) {
      try {
        return dataSnap.docs.firstWhere((d) => d.id == id).data();
      } catch (_) {
        return null;
      }
    }

    // Fetch cloud deletion list before inserting so we never re-insert deleted txns.
    final deletionsDoc = dataDoc('deletions');
    final cloudDeleted = <String>{};
    if (deletionsDoc != null) {
      cloudDeleted.addAll(
          ((deletionsDoc['rawMessages'] as List?) ?? []).cast<String>());
    }

    // Dedup against existing local data (rawMessage is the stable key).
    // Also skip anything in the cloud deletion list.
    // Manual transactions (rawMessage == null) are skipped to avoid duplicates.
    final existing = await _db.allExistingRawMessages();
    final fresh = cloudTxns.where((t) {
      final raw = t.rawMessage;
      if (raw == null) return false;
      if (cloudDeleted.contains(raw)) return false;
      return !existing.contains(raw);
    }).toList();
    if (fresh.isNotEmpty) await _db.insertAll(fresh);

    // Propagate category changes to already-existing transactions.
    // Covers the case where the user recategorized a transaction on another device
    // and pushed — this device's copy gets updated to match (cloud wins on pull).
    for (final t in cloudTxns) {
      final raw = t.rawMessage;
      if (raw == null) continue;
      if (cloudDeleted.contains(raw)) continue;
      if (existing.contains(raw)) {
        await _db.syncCategoryByRawMessage(raw, t.category, t.subCategory);
      }
    }

    // Apply cloud deletions to any active local transactions.
    for (final raw in cloudDeleted) {
      await _db.softDeleteByRawMessage(raw);
    }

    // Import cloud deleted transactions into local deleted list (Option A).
    final existingDeleted = await _db.deletedRawMessages();
    for (final t in cloudDeletedTxns) {
      final raw = t.rawMessage;
      if (raw == null) continue;
      if (!existingDeleted.contains(raw)) await _db.insertDeleted(t);
    }

    // Accounts
    final accDoc = dataDoc('accounts');
    if (accDoc != null) {
      final maps = (accDoc['items'] as List).cast<Map<String, dynamic>>();
      await _db.upsertAccounts(maps.map(BankAccount.fromMap).toList());
    }

    // Rules (ignore-on-conflict so local edits aren't overwritten)
    final ruleDoc = dataDoc('rules');
    if (ruleDoc != null) {
      final maps = (ruleDoc['items'] as List).cast<Map<String, dynamic>>();
      await _db.upsertRules(maps.map(CustomRule.fromMap).toList());
    }

    // Categories
    final catDoc = dataDoc('categories');
    if (catDoc != null) {
      final maps = (catDoc['items'] as List).cast<Map<String, dynamic>>();
      for (final m in maps) {
        await _db.insertCustomCategory(CustomCategory.fromMap(m));
      }
    }

    return SyncResult(
        'Pulled ${fresh.length} new transactions (${cloudTxns.length} in cloud).');
  }

  // ── Delete all cloud data ─────────────────────────────────────────────────

  static Future<void> deleteCloudData() async {
    final userDoc = _userDoc;
    final batch = _fs.batch();

    for (final col in ['months', 'deleted-months', 'data']) {
      final snap = await userDoc.collection(col).get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
    }
    batch.delete(userDoc);
    await batch.commit();
  }

  // ── Last synced timestamp ─────────────────────────────────────────────────

  static Future<DateTime?> lastSyncedAt() async {
    try {
      final doc = await _userDoc.get();
      final ts = doc.data()?['lastSyncedAt'] as Timestamp?;
      return ts?.toDate();
    } catch (_) {
      return null;
    }
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _toCloud(Transaction t) => {
        'amount': t.amount,
        'type': t.type.name,
        'category': t.category,
        'subCategory': t.subCategory,
        'merchant': t.merchant,
        'description': t.description,
        'date': t.date.millisecondsSinceEpoch,
        'rawMessage': t.rawMessage,
      };

  static Transaction _fromCloud(Map<String, dynamic> m) => Transaction(
        amount: (m['amount'] as num).toDouble(),
        type: m['type'] == 'credit' ? TransactionType.credit : TransactionType.debit,
        category: m['category'] as String,
        subCategory: m['subCategory'] as String,
        merchant: m['merchant'] as String,
        description: m['description'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        rawMessage: m['rawMessage'] as String?,
      );
}

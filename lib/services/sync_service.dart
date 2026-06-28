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

    final txns = await _db.queryAll();
    final accounts = await _db.loadAccounts();
    final rules = await _db.loadRules();
    final categories = await _db.loadCustomCategories();

    // Group transactions by YYYY-MM month key
    final byMonth = <String, List<Map<String, dynamic>>>{};
    for (final t in txns) {
      final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      (byMonth[key] ??= []).add(_toCloud(t));
    }

    // Firestore batch (max 500 ops — well within limit for personal use)
    final batch = _fs.batch();

    for (final entry in byMonth.entries) {
      batch.set(
        userDoc.collection('months').doc(entry.key),
        {'transactions': entry.value},
      );
    }

    batch.set(userDoc.collection('data').doc('accounts'),
        {'items': accounts.map((a) => a.toMap()).toList()});
    batch.set(userDoc.collection('data').doc('rules'),
        {'items': rules.map((r) => r.toMap()).toList()});
    batch.set(userDoc.collection('data').doc('categories'),
        {'items': categories.map((c) => c.toMap()).toList()});
    batch.set(
      userDoc,
      {'lastSyncedAt': FieldValue.serverTimestamp(), 'uid': uid},
      SetOptions(merge: true),
    );

    await batch.commit();

    final monthCount = byMonth.length;
    return SyncResult(
        'Pushed ${txns.length} transactions across $monthCount months.');
  }

  // ── Pull — cloud → local ──────────────────────────────────────────────────

  static Future<SyncResult> pull() async {
    final userDoc = _userDoc;

    final monthsSnap = await userDoc.collection('months').get();
    final dataSnap = await userDoc.collection('data').get();

    // Parse all cloud transactions
    final cloudTxns = <Transaction>[];
    for (final doc in monthsSnap.docs) {
      final list =
          (doc.data()['transactions'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
      cloudTxns.addAll(list.map(_fromCloud));
    }

    // Dedup against existing local data (rawMessage is the stable key).
    // Manual transactions (rawMessage == null) are skipped to avoid duplicates.
    final existing = await _db.allExistingRawMessages();
    final fresh = cloudTxns.where((t) {
      final raw = t.rawMessage;
      if (raw == null) return false;
      return !existing.contains(raw);
    }).toList();
    if (fresh.isNotEmpty) await _db.insertAll(fresh);

    // Helper to find a data doc
    Map<String, dynamic>? dataDoc(String id) {
      try {
        return dataSnap.docs.firstWhere((d) => d.id == id).data();
      } catch (_) {
        return null;
      }
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

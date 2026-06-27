import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/bank_account.dart';
import '../models/category_info.dart';
import '../models/custom_category.dart';
import '../models/custom_rule.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/sms_service.dart';

class AppProvider extends ChangeNotifier {
  final _db = DatabaseService();
  final _sms = SmsService();

  DateTime _selectedMonth = DateTime.now();
  List<Transaction> _transactions = [];
  List<BankAccount> _accounts = [];
  List<CustomRule> _rules = [];
  List<CustomCategory> _customCategories = [];
  bool _loading = false;
  String? _error;
  bool _includeNoAccount = false;

  DateTime get selectedMonth => _selectedMonth;
  List<BankAccount> get accounts => _accounts;
  List<CustomRule> get rules => _rules;
  List<CustomCategory> get customCategories => _customCategories;
  bool get loading => _loading;
  String? get error => _error;
  bool get includeNoAccount => _includeNoAccount;

  void _syncCategoryRegistry() {
    updateCategoryRegistry({
      for (final c in _customCategories) c.name: c.toInfo(),
    });
  }

  // ── Custom Categories ─────────────────────────────────────────────────────────

  Future<void> loadCustomCategories() async {
    _customCategories = await _db.loadCustomCategories();
    _syncCategoryRegistry();
    notifyListeners();
  }

  Future<void> addCustomCategory(CustomCategory category) async {
    await _db.insertCustomCategory(category);
    _customCategories = await _db.loadCustomCategories();
    _syncCategoryRegistry();
    notifyListeners();
  }

  Future<void> deleteCustomCategory(String name) async {
    await _db.deleteCustomCategory(name);
    _customCategories.removeWhere((c) => c.name == name);
    _syncCategoryRegistry();
    notifyListeners();
  }

  // Import progress — null means not currently importing.
  String? _importStatus;
  double? _importProgress; // 0.0–1.0 during parse phase; null = indeterminate
  String? get importStatus => _importStatus;
  double? get importProgress => _importProgress;

  bool get hasAccountsConfigured => _accounts.isNotEmpty;

  Set<String> get _trackedLast4Set =>
      _accounts.where((a) => a.isTracked).map((a) => a.last4).toSet();

  List<Transaction> get transactions {
    // Step 1: account filter
    Iterable<Transaction> base = _transactions;
    if (_accounts.isNotEmpty) {
      final tracked = _trackedLast4Set;
      base = base.where((t) {
        if (t.rawMessage == null) return true;
        final last4 = extractLast4(t.rawMessage!);
        if (last4 == null) return _includeNoAccount;
        return tracked.contains(last4);
      });
    }

    // Step 2: apply enabled custom rules instantly — no re-import needed.
    // Extraction rules run first (payee name only, no category change).
    // Categorization rules run second (category only, no name change unless extraction ran).
    final enabled = _rules.where((r) => r.isEnabled).toList();
    if (enabled.isEmpty) return base.toList();

    final extractionRules = enabled.where((r) => r.ruleType == RuleType.merchantExtraction).toList();
    final categorizationRules = enabled.where((r) => r.ruleType == RuleType.categorization).toList();

    return base.map((t) {
      if (t.rawMessage == null) return t;

      String merchant = t.merchant;
      for (final rule in extractionRules) {
        final m = rule.extractMerchant(t.rawMessage!);
        if (m != null && m.isNotEmpty) { merchant = m; break; }
      }

      String category = t.category;
      String subCategory = t.subCategory;
      for (final rule in categorizationRules) {
        if (rule.matchesMessage(t.rawMessage!)) {
          category = rule.category!;
          subCategory = rule.subCategory!;
          break;
        }
      }

      if (merchant == t.merchant && category == t.category && subCategory == t.subCategory) {
        return t;
      }
      return Transaction(
        id: t.id, amount: t.amount, type: t.type,
        category: category, subCategory: subCategory, merchant: merchant,
        description: t.description, date: t.date, rawMessage: t.rawMessage,
      );
    }).toList();
  }

  // ── Computed totals ─────────────────────────────────────────────────────────

  double get totalCredit => transactions
      .where((t) => t.type == TransactionType.credit)
      .fold(0, (s, t) => s + t.amount);

  double get totalDebit => transactions
      .where((t) => t.type == TransactionType.debit)
      .fold(0, (s, t) => s + t.amount);

  Map<String, double> get categoryTotals {
    final map = <String, double>{};
    for (final t in transactions.where((t) => t.type == TransactionType.debit)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  Map<String, double> subCategoryTotals(String category) {
    final map = <String, double>{};
    for (final t in transactions.where(
        (t) => t.type == TransactionType.debit && t.category == category)) {
      map[t.subCategory] = (map[t.subCategory] ?? 0) + t.amount;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  List<Transaction> transactionsForCategory(String category) =>
      transactions.where((t) => t.category == category).toList();

  List<Transaction> transactionsForSubCategory(String cat, String sub) =>
      transactions.where((t) => t.category == cat && t.subCategory == sub).toList();

  // ── Transactions ────────────────────────────────────────────────────────────

  Future<void> loadMonth(DateTime month) async {
    _selectedMonth = month;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _transactions = List<Transaction>.from(await _db.queryMonth(month));
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void changeMonth(int delta) =>
      loadMonth(DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1));

  Future<String> importFromSMS({bool forceFullScan = false}) async {
    if (!Platform.isAndroid) return 'SMS import is only supported on Android.';

    final status = await Permission.sms.request();
    if (!status.isGranted) return 'SMS permission denied. Please grant it in Settings.';

    _loading = true;
    notifyListeners();

    try {
      // forceFullScan ignores the stored timestamp and reads all SMS history.
      final lastStr = forceFullScan ? null : await _db.getSetting('lastImportedAt');
      final sinceMs = lastStr != null ? int.tryParse(lastStr) : null;

      final trackedLast4s = await _db.trackedLast4s();
      final enabledRules = _rules.where((r) => r.isEnabled).toList();

      final result = await _sms.fetchAllNew(
        sinceMs: sinceMs,
        trackedLast4s: trackedLast4s,
        customRules: enabledRules,
        onStatus: (status) {
          _importStatus = status;
          _importProgress = null; // indeterminate until parse phase begins
          notifyListeners();
        },
        onProgress: (done, total) {
          _importStatus = 'Parsing bank messages ($done / $total)…';
          _importProgress = total > 0 ? done / total : 0;
          notifyListeners();
        },
      );

      final parsed = result.transactions;
      final totalRead = result.totalRead;
      final bankCount = result.bankCount;

      if (parsed.isEmpty) {
        return sinceMs == null
            ? 'Read $totalRead SMS — no bank transactions found.'
            : 'No new bank SMS since last import.';
      }

      // Dedup against ALL existing (current + deleted) so deleted ones stay gone.
      final existing = await _db.allExistingRawMessages();
      final fresh = parsed
          .where((t) => t.rawMessage == null || !existing.contains(t.rawMessage))
          .toList();

      await _db.insertAll(fresh);
      await _db.setSetting('lastImportedAt', DateTime.now().millisecondsSinceEpoch.toString());
      await loadMonth(_selectedMonth);

      final isFirst = sinceMs == null;
      if (fresh.isEmpty) {
        return 'Read $totalRead SMS → $bankCount bank messages — all already imported.';
      }
      return isFirst
          ? 'Full scan: $totalRead SMS read → $bankCount bank messages → ${fresh.length} new transactions imported.'
          : 'Imported ${fresh.length} new transaction(s).';
    } catch (e) {
      _error = e.toString();
      return 'Error: $e';
    } finally {
      _loading = false;
      _importStatus = null;
      _importProgress = null;
      notifyListeners();
    }
  }

  Future<void> addManual(Transaction t) async {
    final id = await _db.insert(t);
    _transactions = [t.copyWith(id: id), ..._transactions];
    notifyListeners();
  }

  /// Soft-delete: moves to deleted_transactions table. Import will not re-add it.
  Future<void> deleteTransaction(int id) async {
    await _db.softDelete(id);
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<List<Transaction>> getDeletedTransactions() => _db.getDeletedTransactions();

  Future<void> restoreTransaction(int id) async {
    await _db.restoreDeleted(id);
    await loadMonth(_selectedMonth);
  }

  // ── Accounts ────────────────────────────────────────────────────────────────

  Future<void> loadAccounts() async {
    _accounts = await _db.loadAccounts();
    final noAcctStr = await _db.getSetting('includeNoAccount');
    _includeNoAccount = noAcctStr == 'true';
    notifyListeners();
  }

  Future<void> setIncludeNoAccount(bool v) async {
    _includeNoAccount = v;
    await _db.setSetting('includeNoAccount', v.toString());
    notifyListeners();
  }

  Future<void> discoverAndMergeAccounts() async {
    final discovered = await _sms.discoverAccounts();
    await _db.upsertAccounts(discovered);
    await loadAccounts();
  }

  Future<void> setAccountTracked(String id, bool tracked) async {
    await _db.setAccountTracked(id, tracked);
    final idx = _accounts.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _accounts[idx].isTracked = tracked;
      notifyListeners();
    }
  }

  // ── Custom Rules ─────────────────────────────────────────────────────────────

  Future<void> loadRules() async {
    _rules = await _db.loadRules();
    notifyListeners();
  }

  Future<void> addRule(CustomRule rule) async {
    await _db.insertRule(rule);
    await loadRules();
  }

  Future<void> deleteRule(String id) async {
    await _db.deleteRule(id);
    _rules.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  // ── History (multi-month, for Trends tab) ────────────────────────────────────

  /// Returns transactions for the last [count] months with the same account
  /// filter and rule application as the main [transactions] getter, so values
  /// here match what the Overview tab shows.
  Future<List<({DateTime month, List<Transaction> transactions})>> getHistoryMonths(int count) async {
    final now = DateTime.now();
    final result = <({DateTime month, List<Transaction> transactions})>[];

    // Mirror the transactions getter: account filter + enabled rules.
    final tracked = _trackedLast4Set;
    final enabled = _rules.where((r) => r.isEnabled).toList();
    final extractionRules = enabled.where((r) => r.ruleType == RuleType.merchantExtraction).toList();
    final categorizationRules = enabled.where((r) => r.ruleType == RuleType.categorization).toList();

    for (int i = count - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final rawTxns = await _db.queryMonth(month);

      final txns = rawTxns
          .where((t) {
            // Account filter
            if (_accounts.isEmpty) return true;
            if (t.rawMessage == null) return true;
            final last4 = extractLast4(t.rawMessage!);
            return last4 == null ? _includeNoAccount : tracked.contains(last4);
          })
          .map((t) {
            if (t.rawMessage == null) return t;

            // Extraction rules (merchant name only)
            String merchant = t.merchant;
            for (final rule in extractionRules) {
              final m = rule.extractMerchant(t.rawMessage!);
              if (m != null && m.isNotEmpty) { merchant = m; break; }
            }

            // Categorisation rules (category only)
            String category = t.category;
            String subCategory = t.subCategory;
            for (final rule in categorizationRules) {
              if (rule.matchesMessage(t.rawMessage!)) {
                category = rule.category!;
                subCategory = rule.subCategory!;
                break;
              }
            }

            if (merchant == t.merchant && category == t.category && subCategory == t.subCategory) {
              return t;
            }
            return Transaction(
              id: t.id, amount: t.amount, type: t.type,
              category: category, subCategory: subCategory, merchant: merchant,
              description: t.description, date: t.date, rawMessage: t.rawMessage,
            );
          })
          .toList();

      result.add((month: month, transactions: txns));
    }
    return result;
  }

  Future<String> clearAndRescan() async {
    await _db.clearAllTransactions();
    _transactions = [];
    notifyListeners();
    return importFromSMS(forceFullScan: true);
  }

  Future<void> setRuleEnabled(String id, bool enabled) async {
    await _db.setRuleEnabled(id, enabled);
    final idx = _rules.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _rules[idx] = _rules[idx].copyWith(isEnabled: enabled);
      notifyListeners();
    }
  }
}

// Hide sqflite's Transaction class to avoid conflict with our model.
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/transaction.dart';
import '../models/bank_account.dart';
import '../models/custom_category.dart';
import '../models/custom_rule.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'money_tracker.db');
    return openDatabase(
      path,
      version: 7,
      onCreate: (db, _) async {
        await _createTransactions(db);
        await _createAccounts(db);
        await _createCustomRules(db);
        await _createDeletedTransactions(db);
        await _createSettings(db);
        await _createCustomCategories(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createAccounts(db);
        if (oldVersion < 3) await _createCustomRules(db);
        // v5: schema redesign — drop and recreate rules table
        if (oldVersion >= 3 && oldVersion < 5) {
          await db.execute('DROP TABLE IF EXISTS custom_rules');
          await _createCustomRules(db);
        }
        // v6: soft-delete table + settings table
        if (oldVersion < 6) {
          await _createDeletedTransactions(db);
          await _createSettings(db);
        }
        // v7: user-defined categories
        if (oldVersion < 7) {
          await _createCustomCategories(db);
        }
      },
    );
  }

  Future<void> _createTransactions(Database db) => db.execute('''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL,
      type TEXT NOT NULL,
      category TEXT NOT NULL,
      subCategory TEXT NOT NULL,
      merchant TEXT NOT NULL,
      description TEXT NOT NULL,
      date INTEGER NOT NULL,
      rawMessage TEXT
    )
  ''');

  Future<void> _createAccounts(Database db) => db.execute('''
    CREATE TABLE accounts (
      id TEXT PRIMARY KEY,
      bankCode TEXT NOT NULL,
      last4 TEXT NOT NULL,
      isTracked INTEGER NOT NULL DEFAULT 1
    )
  ''');

  Future<void> _createCustomRules(Database db) => db.execute('''
    CREATE TABLE custom_rules (
      id TEXT PRIMARY KEY,
      ruleType TEXT NOT NULL,
      prefix TEXT,
      terminator TEXT,
      keywords TEXT,
      category TEXT,
      subCategory TEXT,
      isEnabled INTEGER NOT NULL DEFAULT 1,
      createdAt INTEGER NOT NULL
    )
  ''');

  Future<void> _createDeletedTransactions(Database db) => db.execute('''
    CREATE TABLE deleted_transactions (
      id INTEGER PRIMARY KEY,
      amount REAL NOT NULL,
      type TEXT NOT NULL,
      category TEXT NOT NULL,
      subCategory TEXT NOT NULL,
      merchant TEXT NOT NULL,
      description TEXT NOT NULL,
      date INTEGER NOT NULL,
      rawMessage TEXT,
      deletedAt INTEGER NOT NULL
    )
  ''');

  Future<void> _createSettings(Database db) => db.execute('''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');

  Future<void> _createCustomCategories(Database db) => db.execute('''
    CREATE TABLE custom_categories (
      name TEXT PRIMARY KEY,
      colorValue INTEGER NOT NULL,
      iconCodePoint INTEGER NOT NULL
    )
  ''');

  // ── Custom Categories ─────────────────────────────────────────────────────────

  Future<List<CustomCategory>> loadCustomCategories() async {
    final database = await db;
    final maps = await database.query('custom_categories', orderBy: 'name');
    return maps.map(CustomCategory.fromMap).toList();
  }

  Future<void> insertCustomCategory(CustomCategory category) async {
    final database = await db;
    await database.insert('custom_categories', category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCustomCategory(String name) async {
    final database = await db;
    await database.delete('custom_categories', where: 'name = ?', whereArgs: [name]);
  }

  Future<void> clearAllTransactions() async {
    final database = await db;
    await database.delete('transactions');
  }

  Future<List<Transaction>> queryAll() async {
    final database = await db;
    final maps = await database.query('transactions', orderBy: 'date ASC');
    return maps.map(Transaction.fromMap).toList();
  }

  Future<void> upsertRules(List<CustomRule> rules) async {
    final database = await db;
    final batch = database.batch();
    for (final rule in rules) {
      batch.insert('custom_rules', rule.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit();
  }

  // ── Settings ─────────────────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final database = await db;
    final rows = await database.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final database = await db;
    await database.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Custom Rules ─────────────────────────────────────────────────────────────

  Future<List<CustomRule>> loadRules() async {
    final database = await db;
    final maps = await database.query('custom_rules', orderBy: 'createdAt DESC');
    return maps.map(CustomRule.fromMap).toList();
  }

  Future<void> insertRule(CustomRule rule) async {
    final database = await db;
    await database.insert('custom_rules', rule.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteRule(String id) async {
    final database = await db;
    await database.delete('custom_rules', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setRuleEnabled(String id, bool enabled) async {
    final database = await db;
    await database.update('custom_rules', {'isEnabled': enabled ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // ── Transactions ────────────────────────────────────────────────────────────

  Future<int> insert(Transaction t) async {
    final database = await db;
    return database.insert('transactions', t.toMap()..remove('id'));
  }

  Future<void> insertAll(List<Transaction> transactions) async {
    final database = await db;
    final batch = database.batch();
    for (final t in transactions) {
      batch.insert('transactions', t.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<List<Transaction>> queryMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
    final end = DateTime(month.year, month.month + 1, 1).millisecondsSinceEpoch;
    final database = await db;
    final maps = await database.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return maps.map(Transaction.fromMap).toList();
  }

  /// Soft-delete: moves transaction to deleted_transactions table.
  Future<void> softDelete(int id) async {
    final database = await db;
    final rows = await database.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final map = Map<String, dynamic>.from(rows.first);
    map['deletedAt'] = DateTime.now().millisecondsSinceEpoch;
    await database.insert('deleted_transactions', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
    await database.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Restores a soft-deleted transaction back to the main transactions table.
  Future<void> restoreDeleted(int id) async {
    final database = await db;
    final rows = await database.query('deleted_transactions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final map = Map<String, dynamic>.from(rows.first)..remove('deletedAt');
    await database.insert('transactions', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
    await database.delete('deleted_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Transaction>> getDeletedTransactions() async {
    final database = await db;
    final maps = await database.query('deleted_transactions', orderBy: 'deletedAt DESC');
    return maps.map((m) {
      final clean = Map<String, dynamic>.from(m)..remove('deletedAt');
      return Transaction.fromMap(clean);
    }).toList();
  }

  /// All rawMessages in both active AND deleted tables — used for import dedup.
  Future<Set<String>> allExistingRawMessages() async {
    final database = await db;
    final active = await database.query('transactions',
        columns: ['rawMessage'], where: 'rawMessage IS NOT NULL');
    final deleted = await database.query('deleted_transactions',
        columns: ['rawMessage'], where: 'rawMessage IS NOT NULL');
    return {
      ...active.map((m) => m['rawMessage'] as String),
      ...deleted.map((m) => m['rawMessage'] as String),
    };
  }

  // Kept for SMS Debug screen (month-level diagnostics)
  Future<Set<String>> existingRawMessages(DateTime month) async {
    final start = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
    final end = DateTime(month.year, month.month + 1, 1).millisecondsSinceEpoch;
    final database = await db;
    final maps = await database.query(
      'transactions',
      columns: ['rawMessage'],
      where: 'date >= ? AND date < ? AND rawMessage IS NOT NULL',
      whereArgs: [start, end],
    );
    return maps.map((m) => m['rawMessage'] as String).toSet();
  }

  // ── Accounts ────────────────────────────────────────────────────────────────

  Future<List<BankAccount>> loadAccounts() async {
    final database = await db;
    final maps = await database.query('accounts', orderBy: 'bankCode, last4');
    return maps.map(BankAccount.fromMap).toList();
  }

  Future<void> upsertAccount(BankAccount account) async {
    final database = await db;
    await database.insert(
      'accounts',
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> upsertAccounts(List<BankAccount> accounts) async {
    final database = await db;
    final batch = database.batch();
    for (final a in accounts) {
      batch.insert('accounts', a.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> setAccountTracked(String id, bool tracked) async {
    final database = await db;
    await database.update(
      'accounts',
      {'isTracked': tracked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Set<String>> trackedLast4s() async {
    final database = await db;
    final maps = await database.query(
      'accounts',
      columns: ['last4'],
      where: 'isTracked = 1',
    );
    return maps.map((m) => m['last4'] as String).toSet();
  }
}

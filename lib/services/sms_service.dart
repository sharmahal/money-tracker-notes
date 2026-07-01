import 'dart:io';
import 'package:flutter/services.dart';
import '../models/bank_account.dart';
import '../models/custom_rule.dart';
import '../models/transaction.dart';
import 'categorizer_service.dart';
import 'currency_service.dart';

// ─── Bank SMS filter ──────────────────────────────────────────────────────────

String? _whySkipped(String body) {
  final lower = body.toLowerCase();

  final hasDebited  = lower.contains('debited');
  final hasCredited = lower.contains('credited');

  // Future-tense notifications ("will be auto debited", "will be credited") are
  // upcoming scheduled transactions, not actual ones — skip them.
  if ((hasDebited || hasCredited) &&
      (lower.contains('will be') || lower.contains('to be debited') ||
       lower.contains('scheduled'))) {
    return 'future/scheduled transaction — not yet processed';
  }

  // "Auto pay … has been processed" and "EMI … processed" are real debits even
  // though they don't say "debited". Accept if the message also mentions "bank"
  // or a masked account number so we don't catch unrelated "processed" messages.
  final hasProcessed = lower.contains('processed') &&
      (lower.contains('auto') || lower.contains('autopay') ||
       lower.contains('emi') || lower.contains('standing instruction'));

  if (!hasDebited && !hasCredited && !hasProcessed) {
    return 'no "debited", "credited", or autopay-processed keyword';
  }

  // Require either "bank" in the body or a masked account/card number.
  if (!lower.contains('bank') && extractLast4(body) == null) {
    return 'no bank indicator ("bank" keyword or masked account number)';
  }
  return null;
}

// ─── Last-4 account digit extraction ─────────────────────────────────────────

final _kLast4Patterns = [
  // "a/c XXXX1234"  "Ac **1234"  "account no. X1234"
  // Only X/x/* allowed as mask chars — plain digits would match phone numbers.
  RegExp(r'[aA](?:/[cC]|[cC]\.?|ccount\s*(?:no\.?)?)[\s#.:-]*[xX*]{0,10}([0-9]{4})\b'),
  // "card ending 1234"  "card no XX1234"
  RegExp(r'card(?:\s+(?:no|ending|number))?[^0-9]{0,15}[xX*]*([0-9]{4})\b', caseSensitive: false),
  // Generic masked block: "XXXX1234" or "**1234" (requires at least 2 mask chars)
  RegExp(r'[xX*]{2,}([0-9]{4})\b'),
];

String? extractLast4(String body) {
  for (final p in _kLast4Patterns) {
    final m = p.firstMatch(body);
    if (m != null) return m.group(1);
  }
  return null;
}

// ─── Amount extraction ────────────────────────────────────────────────────────

const _kSeparators = [
  '', ' ', '.', '. ', ':', ': ', '-', ' - ', '/', ' /',
];

const _kInrCurrencies = ['₹', 'inr', 'indian rupees', 'rupees', 'rs'];

const _kForeignCurrencies = {
  '€': 'EUR', 'eur': 'EUR', 'euro': 'EUR',
  '£': 'GBP', 'gbp': 'GBP', 'pound': 'GBP',
  r'$': 'USD', 'usd': 'USD', 'dollar': 'USD', 'dollars': 'USD',
};

const _kSymbolCurrencies = {'₹', '€', '£', r'$'};

final _amountRegex = RegExp(r'^\s*([\d,]+(?:\.\d{1,2})?)');

double? _tryAt(String lower, String original, String currency, String sep) {
  final token = '$currency$sep';
  int idx = lower.indexOf(token);
  while (idx != -1) {
    if (!_kSymbolCurrencies.contains(currency) && idx > 0 &&
        RegExp(r'[a-z]').hasMatch(lower[idx - 1])) {
      idx = lower.indexOf(token, idx + token.length);
      continue;
    }
    final m = _amountRegex.firstMatch(original.substring(idx + token.length));
    if (m != null) {
      final n = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (n != null && n > 0) return n;
    }
    idx = lower.indexOf(token, idx + token.length);
  }
  return null;
}

({double amount, String currency})? _extractAmountWithCurrency(String message) {
  final lower = message.toLowerCase();

  for (final curr in _kInrCurrencies) {
    for (final sep in _kSeparators) {
      final n = _tryAt(lower, message, curr, sep);
      if (n != null) return (amount: n, currency: 'INR');
    }
  }
  for (final entry in _kForeignCurrencies.entries) {
    for (final sep in _kSeparators) {
      final n = _tryAt(lower, message, entry.key, sep);
      if (n != null) return (amount: n, currency: entry.value);
    }
  }

  for (final p in [
    RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*(?:rs|inr|rupees)', caseSensitive: false),
    RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*₹'),
  ]) {
    final m = p.firstMatch(message);
    if (m != null) {
      final n = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (n != null && n > 0) return (amount: n, currency: 'INR');
    }
  }

  return null;
}

// ─── Transaction type ──────────────────────────────────────────────────────────

TransactionType? _extractType(String msg) {
  final lower = msg.toLowerCase();
  if (lower.contains('debited') || lower.contains('withdrawn') ||
      lower.contains('spent') || lower.contains('paid') ||
      lower.contains('payment') || lower.contains('purchase') ||
      lower.contains('transferred to')) {
    return TransactionType.debit;
  }
  if (lower.contains('credited') || lower.contains('received') ||
      lower.contains('deposited') || lower.contains('refund') ||
      lower.contains('transferred from')) {
    return TransactionType.credit;
  }
  // Auto pay / EMI / standing instruction "processed" → treat as debit
  if (lower.contains('processed') &&
      (lower.contains('auto') || lower.contains('autopay') ||
       lower.contains('emi') || lower.contains('standing instruction'))) {
    return TransactionType.debit;
  }
  return null;
}

// ─── Merchant extraction ──────────────────────────────────────────────────────

final _merchantPatterns = [
  RegExp(r'FVG:\s*(.+?)\s+Avl\s*Bal', caseSensitive: false),
  RegExp(r'FVG[:\s]+([A-Za-z0-9].+?)(?=\s+Ref\b|\s+UPI\b|\s*[,.](?:\s|$))', caseSensitive: false),
  RegExp(r'VPA\s+([\w@.-]+)', caseSensitive: false),
  RegExp(r'Info:\s*(?:UPI/[\d]+/)?([\w][\w\s@&.-]{2,40}?)(?:\s*\.|$|\s+Ref|\s+UPI|\s+on\s)', caseSensitive: false),
  RegExp(r'paid\s+to\s+([A-Za-z][\w\s&@.()\-]{2,35}?)(?:\s+on\b|\s+via\b|\s+Ref|\s*\.|\s*$)', caseSensitive: false),
  RegExp(r'transferred\s+to\s+([A-Za-z][\w\s&@.()\-]{2,35}?)(?:\s+on\b|\s+via\b|\s+Ref|\s*\.|\s*$)', caseSensitive: false),
  RegExp(r'\bto\s+([A-Z][\w\s&@.()\-]{2,35}?)(?:\s+on\b|\s+via\b|\s+a/c|\s+Ref|\s*\.|\s*$)', caseSensitive: false),
  RegExp(r'\bat\s+([A-Z][\w\s&@.()\-]{2,35}?)(?:\s+on\b|\s+via\b|\s+Ref|\s*\.)', caseSensitive: false),
  RegExp(r'\bfor\s+([A-Z][\w\s&@.()\-]{2,35}?)(?:\s+on\b|\s+via\b|\s*\.)', caseSensitive: false),
];

String _extractMerchant(String msg) {
  for (final p in _merchantPatterns) {
    final m = p.firstMatch(msg);
    if (m != null) {
      final raw = m.group(1)?.trim() ?? '';
      if (raw.length > 2) return raw;
    }
  }
  return 'Unknown';
}

// ─── Raw SMS record (replaces flutter_sms_inbox's SmsMessage) ─────────────────

typedef _Sms = ({String address, String body, DateTime date});

// ─── Debug entry ──────────────────────────────────────────────────────────────

class SmsDebugEntry {
  final String sender;
  final String body;
  final DateTime date;
  final String? last4;
  final String? filterReason;
  final double? amount;
  final String? currency;
  final TransactionType? type;
  final String? merchant;

  bool get isBank =>
      filterReason == null || filterReason!.startsWith('passed filter');
  bool get isParsed =>
      filterReason == null && amount != null && type != null;

  const SmsDebugEntry({
    required this.sender,
    required this.body,
    required this.date,
    this.last4,
    this.filterReason,
    this.amount,
    this.currency,
    this.type,
    this.merchant,
  });
}

// ─── Service ──────────────────────────────────────────────────────────────────

class SmsService {
  static const _kChannel = MethodChannel('money_tracker/sms');

  /// Reads SMS from the Android inbox via a native MethodChannel with no
  /// artificial count cap. [sinceMs] is an exclusive lower bound on the
  /// message date (epoch ms); pass null to read all messages ever.
  Future<List<_Sms>> _readNative({int? sinceMs}) async {
    if (!Platform.isAndroid) return [];
    try {
      final args = <String, dynamic>{};
      if (sinceMs != null) args['sinceMs'] = sinceMs;
      final dynamic raw = await _kChannel.invokeMethod('readInbox', args);
      if (raw is! List) return [];
      return raw.map((item) {
        final m = item as Map;
        final dateMs = m['date'];
        final date = dateMs != null
            ? DateTime.fromMillisecondsSinceEpoch(
                dateMs is int ? dateMs : (dateMs as num).toInt())
            : DateTime.now();
        return (
          address: (m['address'] as String?) ?? '',
          body: (m['body'] as String?) ?? '',
          date: date,
        );
      }).toList();
    } on PlatformException {
      return [];
    }
  }

  /// Returns all SMS in [month] using the native channel.
  Future<List<_Sms>> _readMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    // Query since the day before month start to keep the SQL simple, then
    // filter the end boundary in Dart.
    final all = await _readNative(sinceMs: start.millisecondsSinceEpoch - 1);
    return all.where((s) => s.date.isBefore(end)).toList();
  }

  /// Reads all available SMS (or only those newer than [sinceMs]) and parses
  /// them into transactions. The native channel handles the date filter at SQL
  /// level, so no count limits apply.
  Future<({List<Transaction> transactions, int totalRead, int bankCount})> fetchAllNew({
    int? sinceMs,
    Set<String> trackedLast4s = const {},
    List<CustomRule> customRules = const [],
    String baseCurrency = 'INR',
    void Function(String status)? onStatus,
    void Function(int done, int total)? onProgress,
  }) async {
    if (!Platform.isAndroid) return (transactions: <Transaction>[], totalRead: 0, bankCount: 0);

    // ── Phase 1: read from Android inbox ──────────────────────────────────────
    onStatus?.call(sinceMs == null ? 'Reading all SMS from phone…' : 'Checking for new SMS…');

    final all = await _readNative(sinceMs: sinceMs);
    onStatus?.call('Read ${all.length} messages, filtering bank SMS…');

    // ── Phase 2: pre-filter ────────────────────────────────────────────────────
    final smsExtractionRules = customRules.where((r) => r.ruleType == RuleType.smsExtraction).toList();
    final bankMessages = <_Sms>[];
    for (final sms in all) {
      if (_whySkipped(sms.body) != null) {
        // A custom SMS extraction rule can rescue an otherwise-skipped message.
        if (smsExtractionRules.any((r) => r.extractAmount(sms.body) != null)) {
          bankMessages.add(sms);
        }
        continue;
      }
      bankMessages.add(sms);
    }

    if (bankMessages.isEmpty) {
      return (transactions: const <Transaction>[], totalRead: all.length, bankCount: 0);
    }

    // ── Phase 3: parse with progress ──────────────────────────────────────────
    onStatus?.call('Parsing ${bankMessages.length} bank messages…');
    onProgress?.call(0, bankMessages.length);

    final results = <Transaction>[];
    for (int i = 0; i < bankMessages.length; i++) {
      final sms = bankMessages[i];
      final body = sms.body;

      if (trackedLast4s.isNotEmpty) {
        final last4 = extractLast4(body);
        if (last4 != null && !trackedLast4s.contains(last4)) continue;
      }

      final extracted = _extractAmountWithCurrency(body);
      if (extracted == null) continue;

      final type = _extractType(body);
      if (type == null) continue;

      double amount = extracted.amount;
      String desc = body.length > 120 ? body.substring(0, 120) : body;
      if (extracted.currency != baseCurrency) {
        amount = await CurrencyService().convert(extracted.amount, extracted.currency, baseCurrency);
        desc = '[${extracted.currency} ${extracted.amount.toStringAsFixed(2)} → $baseCurrency ${amount.toStringAsFixed(0)}] $desc';
      }

      String? customMerchant;
      for (final rule in customRules.where((r) => r.ruleType == RuleType.merchantExtraction)) {
        final m = rule.extractMerchant(body);
        if (m != null && m.isNotEmpty) { customMerchant = m; break; }
      }
      final merchant = customMerchant ?? _extractMerchant(body);

      CustomRule? catRule;
      for (final rule in customRules.where((r) => r.ruleType == RuleType.categorization)) {
        if (rule.matchesMessage(body)) { catRule = rule; break; }
      }
      final cat = catRule != null
          ? (category: catRule.category!, subCategory: catRule.subCategory!)
          : categorize(merchant, body);

      results.add(Transaction(
        amount: amount,
        type: type,
        category: cat.category,
        subCategory: cat.subCategory,
        merchant: merchant,
        description: desc,
        date: sms.date,
        rawMessage: body,
      ));

      if ((i + 1) % 50 == 0 || i == bankMessages.length - 1) {
        onProgress?.call(i + 1, bankMessages.length);
      }
    }
    return (transactions: results, totalRead: all.length, bankCount: bankMessages.length);
  }

  /// Scans the last [months] months of SMS and returns every unique bank
  /// account (sender + last-4 combination) found.
  Future<List<BankAccount>> discoverAccounts({int months = 6}) async {
    if (!Platform.isAndroid) return [];

    final since = DateTime.now().subtract(Duration(days: months * 31));
    final all = await _readNative(sinceMs: since.millisecondsSinceEpoch);

    final seen = <String, BankAccount>{};
    for (final sms in all) {
      final body = sms.body;
      if (_whySkipped(body) != null) continue;

      final last4 = extractLast4(body);
      if (last4 == null) continue;

      final bankCode = BankAccount.bankCodeFrom(sms.address);
      final id = BankAccount.makeId(bankCode, last4);

      seen.putIfAbsent(id, () => BankAccount(
            id: id,
            bankCode: bankCode,
            last4: last4,
            isTracked: true,
          ));
    }
    return seen.values.toList()
      ..sort((a, b) => a.displayLabel.compareTo(b.displayLabel));
  }

  /// Fetches transactions for [month], filtered to [trackedLast4s].
  Future<List<Transaction>> fetchForMonth(
    DateTime month, {
    Set<String> trackedLast4s = const {},
    List<CustomRule> customRules = const [],
    String baseCurrency = 'INR',
  }) async {
    if (!Platform.isAndroid) return [];

    final smsExtractionRules = customRules.where((r) => r.ruleType == RuleType.smsExtraction).toList();
    final results = <Transaction>[];
    for (final sms in await _readMonth(month)) {
      final body = sms.body;
      if (_whySkipped(body) != null) {
        if (smsExtractionRules.any((r) => r.extractAmount(body) != null)) {
          // rescued by custom extraction rule — fall through
        } else {
          continue;
        }
      }

      if (trackedLast4s.isNotEmpty) {
        final last4 = extractLast4(body);
        if (last4 != null && !trackedLast4s.contains(last4)) continue;
      }

      var extracted = _extractAmountWithCurrency(body);
      CustomRule? matchedSmsRule;
      if (extracted == null) {
        for (final rule in customRules.where((r) => r.ruleType == RuleType.smsExtraction)) {
          final amt = rule.extractAmount(body);
          if (amt != null) {
            extracted = (amount: amt, currency: baseCurrency);
            matchedSmsRule = rule;
            break;
          }
        }
      }
      if (extracted == null) continue;

      TransactionType? type;
      if (matchedSmsRule != null) {
        type = matchedSmsRule.forcedType == 'credit'
            ? TransactionType.credit
            : TransactionType.debit;
      } else {
        type = _extractType(body);
      }
      if (type == null) continue;

      double amount = extracted.amount;
      String desc = body.length > 120 ? body.substring(0, 120) : body;
      if (extracted.currency != baseCurrency) {
        amount = await CurrencyService().convert(extracted.amount, extracted.currency, baseCurrency);
        desc = '[${extracted.currency} ${extracted.amount.toStringAsFixed(2)} → $baseCurrency ${amount.toStringAsFixed(0)}] $desc';
      }

      String? customMerchant;
      for (final rule in customRules.where((r) => r.ruleType == RuleType.merchantExtraction)) {
        final m = rule.extractMerchant(body);
        if (m != null && m.isNotEmpty) { customMerchant = m; break; }
      }
      final merchant = customMerchant ?? _extractMerchant(body);

      CustomRule? catRule;
      for (final rule in customRules.where((r) => r.ruleType == RuleType.categorization)) {
        if (rule.matchesMessage(body)) { catRule = rule; break; }
      }
      final cat = catRule != null
          ? (category: catRule.category!, subCategory: catRule.subCategory!)
          : categorize(merchant, body);

      results.add(Transaction(
        amount: amount,
        type: type,
        category: cat.category,
        subCategory: cat.subCategory,
        merchant: merchant,
        description: desc,
        date: sms.date,
        rawMessage: body,
      ));
    }
    return results;
  }

  /// Full diagnostic — every SMS in the month, annotated with why it was
  /// skipped or what was parsed from it.
  /// [month] null = all available bank SMS; non-null = that calendar month only.
  Future<List<SmsDebugEntry>> diagnose({DateTime? month}) async {
    if (!Platform.isAndroid) return [];

    final smsList = month != null ? await _readMonth(month) : await _readNative();

    final entries = <SmsDebugEntry>[];
    for (final sms in smsList) {
      final body = sms.body;
      final sender = sms.address;
      final date = sms.date;
      final last4 = extractLast4(body);

      final filterReason = _whySkipped(body);
      if (filterReason != null) {
        entries.add(SmsDebugEntry(
            sender: sender, body: body, date: date,
            last4: last4, filterReason: filterReason));
        continue;
      }

      final extracted = _extractAmountWithCurrency(body);
      final type = _extractType(body);

      String? reason;
      if (extracted == null) {
        reason = 'passed filter but amount not found';
      } else if (type == null) {
        reason = 'passed filter but debit/credit direction unclear';
      }

      entries.add(SmsDebugEntry(
        sender: sender, body: body, date: date, last4: last4,
        filterReason: reason,
        amount: extracted?.amount,
        currency: extracted?.currency,
        type: type,
        merchant: (extracted != null && type != null) ? _extractMerchant(body) : null,
      ));
    }

    // Newest first.
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }
}

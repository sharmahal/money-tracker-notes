import 'package:intl/intl.dart';
import '../models/currency_info.dart';

// Configured once at startup by AppProvider when the user's currency setting loads.
// Defaults to INR so existing behaviour is unchanged if never called.
String _symbol = '₹';
String _locale = 'en_IN';
NumberFormat _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
NumberFormat _fmtDecimal = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

void configureCurrency(String currencyCode) {
  final meta = currencyMeta(currencyCode);
  _symbol = meta.symbol;
  _locale = meta.locale;
  _fmt = NumberFormat.currency(locale: _locale, symbol: _symbol, decimalDigits: 0);
  _fmtDecimal = NumberFormat.currency(locale: _locale, symbol: _symbol, decimalDigits: 2);
}

String get activeCurrencyCode {
  final match = kCurrencies.where((c) => c.symbol == _symbol);
  return match.isNotEmpty ? match.first.code : 'INR';
}

String formatAmount(double amount, {bool showPaise = false}) =>
    showPaise ? _fmtDecimal.format(amount) : _fmt.format(amount);

final _monthFmt = DateFormat('MMMM yyyy');
final _dateFmt = DateFormat('d MMM');
final _fullDateFmt = DateFormat('d MMM yyyy, h:mm a');

String formatMonth(DateTime dt) => _monthFmt.format(dt);

String formatDate(DateTime dt) => _dateFmt.format(dt);

String formatFullDate(DateTime dt) => _fullDateFmt.format(dt);

String formatPercent(double value, double total) {
  if (total == 0) return '0%';
  return '${(value / total * 100).toStringAsFixed(1)}%';
}

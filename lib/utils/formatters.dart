import 'package:intl/intl.dart';

final _currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _currencyFmtDecimal = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _monthFmt = DateFormat('MMMM yyyy');
final _dateFmt = DateFormat('d MMM');
final _fullDateFmt = DateFormat('d MMM yyyy, h:mm a');

String formatAmount(double amount, {bool showPaise = false}) =>
    showPaise ? _currencyFmtDecimal.format(amount) : _currencyFmt.format(amount);

String formatMonth(DateTime dt) => _monthFmt.format(dt);

String formatDate(DateTime dt) => _dateFmt.format(dt);

String formatFullDate(DateTime dt) => _fullDateFmt.format(dt);

String formatPercent(double value, double total) {
  if (total == 0) return '0%';
  return '${(value / total * 100).toStringAsFixed(1)}%';
}

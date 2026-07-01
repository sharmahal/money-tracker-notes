import 'dart:convert';
import 'dart:io';

/// Converts amounts between currencies.
/// Rates are fetched from frankfurter.app (free, no API key) and cached for 6 h.
/// Falls back to hardcoded approximate rates (vs USD) when network is unavailable.
class CurrencyService {
  static final CurrencyService _instance = CurrencyService._();
  factory CurrencyService() => _instance;
  CurrencyService._();

  final Map<String, _CachedRate> _cache = {};

  // Approximate rates relative to USD (updated periodically in code)
  static const Map<String, double> _fallbackVsUsd = {
    'USD': 1.0,
    'INR': 83.5,
    'EUR': 0.92,
    'GBP': 0.79,
    'AED': 3.67,
    'SGD': 1.34,
    'AUD': 1.53,
    'CAD': 1.36,
    'JPY': 149.5,
    'CNY': 7.24,
    'CHF': 0.89,
    'BRL': 4.97,
    'NGN': 1550.0,
    'PKR': 278.0,
    'BDT': 110.0,
    'MYR': 4.72,
    'PHP': 56.5,
    'IDR': 15750.0,
    'KES': 129.0,
    'ZAR': 18.6,
  };

  /// Convert [amount] in [fromCurrency] to [toCurrency].
  Future<double> convert(double amount, String fromCurrency, String toCurrency) async {
    if (fromCurrency == toCurrency) return amount;
    final rate = await _rate(fromCurrency, toCurrency);
    return amount * rate;
  }

  Future<double> _rate(String from, String to) async {
    final key = '$from→$to';
    final cached = _cache[key];
    if (cached != null && cached.isValid) return cached.rate;

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(
        Uri.parse('https://api.frankfurter.app/latest?from=$from&to=$to'),
      );
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final rate = (json['rates'][to] as num).toDouble();
        _cache[key] = _CachedRate(rate);
        client.close();
        return rate;
      }
      client.close();
    } catch (_) {
      // Network unavailable — use hardcoded fallback
    }

    // Fallback: convert via USD
    final fromUsd = _fallbackVsUsd[from] ?? 1.0;
    final toUsd = _fallbackVsUsd[to] ?? 1.0;
    return toUsd / fromUsd;
  }
}

class _CachedRate {
  final double rate;
  final DateTime _at;
  _CachedRate(this.rate) : _at = DateTime.now();
  bool get isValid => DateTime.now().difference(_at).inHours < 6;
}

import 'dart:convert';
import 'dart:io';

/// Converts foreign currency amounts to INR.
/// Rates are fetched from frankfurter.app (free, no API key) and cached for 6 h.
/// Falls back to hardcoded approximate rates when the network is unavailable.
class CurrencyService {
  static final CurrencyService _instance = CurrencyService._();
  factory CurrencyService() => _instance;
  CurrencyService._();

  final Map<String, _CachedRate> _cache = {};

  static const Map<String, double> _fallbackRates = {
    'USD': 83.5,
    'EUR': 91.0,
    'GBP': 106.0,
    'AED': 22.7,
    'SGD': 62.0,
    'AUD': 54.0,
    'CAD': 61.5,
    'JPY': 0.56,
    'CNY': 11.5,
    'CHF': 94.0,
  };

  Future<double> toInr(double amount, String fromCurrency) async {
    if (fromCurrency == 'INR') return amount;
    final rate = await _rateToInr(fromCurrency);
    return amount * rate;
  }

  Future<double> _rateToInr(String currency) async {
    final cached = _cache[currency];
    if (cached != null && cached.isValid) return cached.rate;

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(
        Uri.parse('https://api.frankfurter.app/latest?from=$currency&to=INR'),
      );
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final rate = (json['rates']['INR'] as num).toDouble();
        _cache[currency] = _CachedRate(rate);
        client.close();
        return rate;
      }
      client.close();
    } catch (_) {
      // Network unavailable or API error — fall through to hardcoded rate.
    }

    return _fallbackRates[currency] ?? 83.5;
  }
}

class _CachedRate {
  final double rate;
  final DateTime _at;
  _CachedRate(this.rate) : _at = DateTime.now();
  bool get isValid => DateTime.now().difference(_at).inHours < 6;
}

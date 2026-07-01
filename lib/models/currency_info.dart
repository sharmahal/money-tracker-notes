class CurrencyMeta {
  final String code;
  final String symbol;
  final String name;
  final String locale;

  const CurrencyMeta({
    required this.code,
    required this.symbol,
    required this.name,
    required this.locale,
  });
}

const List<CurrencyMeta> kCurrencies = [
  CurrencyMeta(code: 'INR', symbol: '₹',   name: 'Indian Rupee',        locale: 'en_IN'),
  CurrencyMeta(code: 'USD', symbol: '\$',   name: 'US Dollar',           locale: 'en_US'),
  CurrencyMeta(code: 'EUR', symbol: '€',    name: 'Euro',                locale: 'en_EU'),
  CurrencyMeta(code: 'GBP', symbol: '£',    name: 'British Pound',       locale: 'en_GB'),
  CurrencyMeta(code: 'AED', symbol: 'AED ', name: 'UAE Dirham',          locale: 'en_AE'),
  CurrencyMeta(code: 'SGD', symbol: 'S\$',  name: 'Singapore Dollar',    locale: 'en_SG'),
  CurrencyMeta(code: 'AUD', symbol: 'A\$',  name: 'Australian Dollar',   locale: 'en_AU'),
  CurrencyMeta(code: 'CAD', symbol: 'C\$',  name: 'Canadian Dollar',     locale: 'en_CA'),
  CurrencyMeta(code: 'JPY', symbol: '¥',    name: 'Japanese Yen',        locale: 'ja_JP'),
  CurrencyMeta(code: 'CNY', symbol: 'CN¥',  name: 'Chinese Yuan',        locale: 'zh_CN'),
  CurrencyMeta(code: 'CHF', symbol: 'Fr ',  name: 'Swiss Franc',         locale: 'de_CH'),
  CurrencyMeta(code: 'BRL', symbol: 'R\$',  name: 'Brazilian Real',      locale: 'pt_BR'),
  CurrencyMeta(code: 'NGN', symbol: '₦',    name: 'Nigerian Naira',      locale: 'en_NG'),
  CurrencyMeta(code: 'PKR', symbol: '₨',    name: 'Pakistani Rupee',     locale: 'ur_PK'),
  CurrencyMeta(code: 'BDT', symbol: '৳',    name: 'Bangladeshi Taka',    locale: 'en_BD'),
  CurrencyMeta(code: 'MYR', symbol: 'RM ',  name: 'Malaysian Ringgit',   locale: 'ms_MY'),
  CurrencyMeta(code: 'PHP', symbol: '₱',    name: 'Philippine Peso',     locale: 'en_PH'),
  CurrencyMeta(code: 'IDR', symbol: 'Rp ',  name: 'Indonesian Rupiah',   locale: 'id_ID'),
  CurrencyMeta(code: 'KES', symbol: 'KSh ', name: 'Kenyan Shilling',     locale: 'en_KE'),
  CurrencyMeta(code: 'ZAR', symbol: 'R ',   name: 'South African Rand',  locale: 'en_ZA'),
];

CurrencyMeta currencyMeta(String code) =>
    kCurrencies.firstWhere((c) => c.code == code,
        orElse: () => kCurrencies.first);

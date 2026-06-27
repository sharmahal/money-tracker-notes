// Sender codes → display names for common Indian banks / UPI apps.
const Map<String, String> _kBankNames = {
  'HDFCBK': 'HDFC Bank',
  'ICICIB': 'ICICI Bank',
  'ICICI' : 'ICICI Bank',
  'SBIINB': 'SBI',
  'SBIALR': 'SBI',
  'SBIBNK': 'SBI',
  'AXISBK': 'Axis Bank',
  'KOTAKB': 'Kotak Bank',
  'INDUSB': 'IndusInd Bank',
  'YESBNK': 'Yes Bank',
  'PAYTMB': 'Paytm Bank',
  'PAYTM' : 'Paytm',
  'IDFCBK': 'IDFC First Bank',
  'BOIIND': 'Bank of India',
  'PNBSMS': 'PNB',
  'CANBNK': 'Canara Bank',
  'UNIONB': 'Union Bank',
  'SCBANK': 'Standard Chartered',
  'CITIBK': 'Citibank',
  'HSBCIN': 'HSBC',
  'RBLBNK': 'RBL Bank',
  'AUSMFB': 'AU Small Finance Bank',
  'FEDERL': 'Federal Bank',
  'KARBNK': 'Karnataka Bank',
  'DBS'   : 'DBS Bank',
  'AMEXIN': 'American Express',
  'PHONEPE': 'PhonePe',
  'GPAY'  : 'Google Pay',
  'AMAZON': 'Amazon Pay',
  'BAJAJI': 'Bajaj Finserv',
  'CBSSBI': 'SBI',
};

class BankAccount {
  final String id;        // "HDFCBK_4521"
  final String bankCode;  // "HDFCBK" (from sender address)
  final String last4;     // "4521"
  bool isTracked;

  BankAccount({
    required this.id,
    required this.bankCode,
    required this.last4,
    this.isTracked = true,
  });

  String get bankName => _kBankNames[bankCode] ?? bankCode;
  String get maskedNumber => '****$last4';
  String get displayLabel => '$bankName  $maskedNumber';

  // Derive a stable bank code from the raw SMS sender address.
  // "VM-HDFCBK" → "HDFCBK",  "AM-ICICIB" → "ICICIB",  "+919876543210" → "9876543210"
  static String bankCodeFrom(String sender) {
    final parts = sender.toUpperCase().split('-');
    return parts.length > 1 ? parts.last : sender.replaceAll('+', '');
  }

  static String makeId(String bankCode, String last4) => '${bankCode}_$last4';

  Map<String, dynamic> toMap() => {
        'id': id,
        'bankCode': bankCode,
        'last4': last4,
        'isTracked': isTracked ? 1 : 0,
      };

  factory BankAccount.fromMap(Map<String, dynamic> m) => BankAccount(
        id: m['id'] as String,
        bankCode: m['bankCode'] as String,
        last4: m['last4'] as String,
        isTracked: (m['isTracked'] as int) == 1,
      );
}

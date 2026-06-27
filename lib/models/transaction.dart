enum TransactionType { credit, debit }

class Transaction {
  final int? id;
  final double amount;
  final TransactionType type;
  final String category;
  final String subCategory;
  final String merchant;
  final String description;
  final DateTime date;
  final String? rawMessage;

  const Transaction({
    this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.subCategory,
    required this.merchant,
    required this.description,
    required this.date,
    this.rawMessage,
  });

  Transaction copyWith({int? id}) => Transaction(
        id: id ?? this.id,
        amount: amount,
        type: type,
        category: category,
        subCategory: subCategory,
        merchant: merchant,
        description: description,
        date: date,
        rawMessage: rawMessage,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'type': type.name,
        'category': category,
        'subCategory': subCategory,
        'merchant': merchant,
        'description': description,
        'date': date.millisecondsSinceEpoch,
        'rawMessage': rawMessage,
      };

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
        id: map['id'] as int?,
        amount: (map['amount'] as num).toDouble(),
        type: map['type'] == 'credit' ? TransactionType.credit : TransactionType.debit,
        category: map['category'] as String,
        subCategory: map['subCategory'] as String,
        merchant: map['merchant'] as String,
        description: map['description'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        rawMessage: map['rawMessage'] as String?,
      );
}

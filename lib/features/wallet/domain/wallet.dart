import 'package:equatable/equatable.dart';

enum TxnType { topup, bonus, charge }

class WalletTxn extends Equatable {
  const WalletTxn({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.note,
    required this.createdAt,
    this.sessionId,
    this.astrologerName,
  });

  final String id;
  final TxnType type;

  /// Signed rupees: credits positive, debits negative.
  final int amount;
  final int balanceAfter;
  final String note;
  final DateTime createdAt;
  final String? sessionId;
  final String? astrologerName;

  bool get isCredit => amount > 0;

  factory WalletTxn.fromJson(Map<String, dynamic> j) => WalletTxn(
        id: j['id'] as String,
        type: TxnType.values.byName(j['type'] as String),
        amount: (j['amount'] as num).toInt(),
        balanceAfter: (j['balanceAfter'] as num).toInt(),
        note: j['note'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        sessionId: j['sessionId'] as String?,
        astrologerName: j['astrologerName'] as String?,
      );

  @override
  List<Object?> get props => [id, amount, balanceAfter];
}

class Wallet extends Equatable {
  const Wallet({
    this.balance = 0,
    this.minTopUp = 10,
    this.maxTopUp = 10000,
    this.transactions = const [],
  });

  static const empty = Wallet();

  /// Whole rupees.
  final int balance;
  final int minTopUp;
  final int maxTopUp;
  final List<WalletTxn> transactions;

  bool canAfford(int rupees) => balance >= rupees;

  Wallet copyWith({int? balance, List<WalletTxn>? transactions}) => Wallet(
        balance: balance ?? this.balance,
        minTopUp: minTopUp,
        maxTopUp: maxTopUp,
        transactions: transactions ?? this.transactions,
      );

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        balance: (j['balance'] as num).toInt(),
        minTopUp: (j['minTopUp'] as num?)?.toInt() ?? 10,
        maxTopUp: (j['maxTopUp'] as num?)?.toInt() ?? 10000,
        transactions: ((j['transactions'] as List?) ?? const [])
            .map((t) => WalletTxn.fromJson(t as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [balance, minTopUp, maxTopUp, transactions];
}

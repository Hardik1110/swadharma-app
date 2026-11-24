import 'hub.dart';
import 'models.dart';
import 'store.dart';

class WalletConfig {
  const WalletConfig({
    this.welcomeBonus = 100,
    this.minTopUp = 10,
    this.maxTopUp = 10000,
  });

  /// Credited once to every new account (rupees).
  final int welcomeBonus;
  final int minTopUp;
  final int maxTopUp;
}

/// Prepaid wallet: balance on the user, a ledger in the store, and a
/// `wallet.updated` push after every change so the app's balance is live.
///
/// Top-ups are simulated (no payment gateway); the call site is where a real
/// gateway such as Razorpay would confirm a payment before crediting.
class WalletService {
  WalletService(this.store, this.hub, {this.config = const WalletConfig()});

  final Store store;
  final Hub hub;
  final WalletConfig config;

  /// Credits the welcome bonus the first time an account is seen.
  void ensureInitialized(User user) {
    if (user.walletInitialized) return;
    user.walletInitialized = true;
    if (config.welcomeBonus > 0) {
      _apply(user, TxnType.bonus, config.welcomeBonus, 'Welcome bonus');
    } else {
      store.scheduleSave();
    }
  }

  WalletTxn topUp(User user, int amount) {
    if (amount < config.minTopUp || amount > config.maxTopUp) {
      throw ApiError(400, 'invalid_amount',
          'Enter an amount between ₹${config.minTopUp} and ₹${config.maxTopUp}');
    }
    return _apply(user, TxnType.topup, amount, 'Added money (demo payment)');
  }

  /// Deducts [amount]. Returns false (and changes nothing) if the balance is
  /// too low.
  bool charge(User user, int amount, {required String note, Session? session}) {
    if (user.balance < amount) return false;
    final astro = session == null ? null : store.astrologers[session.astrologerId]?.name;
    _apply(user, TxnType.charge, -amount, note,
        sessionId: session?.id, astrologerName: astro);
    return true;
  }

  List<WalletTxn> history(User user, {int limit = 100}) {
    final list = store.transactions.where((t) => t.userId == user.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  Map<String, dynamic> summary(User user) => {
        'balance': user.balance,
        'minTopUp': config.minTopUp,
        'maxTopUp': config.maxTopUp,
        'transactions': history(user).map((t) => t.toJson()).toList(),
      };

  WalletTxn _apply(User user, TxnType type, int amount, String note,
      {String? sessionId, String? astrologerName}) {
    user.balance += amount;
    final txn = WalletTxn(
      id: newId(6),
      userId: user.id,
      type: type,
      amount: amount,
      balanceAfter: user.balance,
      note: note,
      sessionId: sessionId,
      astrologerName: astrologerName,
    );
    store.transactions.add(txn);
    store.scheduleSave();
    hub.toUser(user.id, 'wallet.updated', {'balance': user.balance});
    return txn;
  }
}

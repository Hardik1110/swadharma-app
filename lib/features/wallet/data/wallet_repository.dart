import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/wallet.dart';

final walletRepositoryProvider =
    Provider((ref) => WalletRepository(ref.watch(apiClientProvider)));

class WalletRepository {
  WalletRepository(this._api);

  final ApiClient _api;

  Future<Wallet> load() async =>
      Wallet.fromJson(await _api.get<Map<String, dynamic>>('/wallet'));

  /// Demo payment: the server credits the amount immediately. A payment
  /// gateway would confirm the charge before this call.
  Future<Wallet> topUp(int amount) async => Wallet.fromJson(
      await _api.post<Map<String, dynamic>>('/wallet/topup', {'amount': amount}));
}

import 'package:astro_connect/features/wallet/domain/wallet.dart';
import 'package:astro_connect/features/wallet/presentation/pages/wallet_page.dart';
import 'package:astro_connect/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'harness.dart';

WalletTxn _t(String id, TxnType type, int amount, int after, String at,
        {String note = '', String? astro, String? session}) =>
    WalletTxn(
      id: id,
      type: type,
      amount: amount,
      balanceAfter: after,
      note: note,
      createdAt: DateTime.parse(at),
      astrologerName: astro,
      sessionId: session,
    );

void main() {
  testWidgets('wallet', (t) => snapshot(
        t,
        'wallet',
        const WalletPage(),
        size: const Size(390, 900),
        overrides: [
          walletProvider.overrideWith(() => FakeWalletNotifier(balance: 175, transactions: [
                _t('4', TxnType.charge, -25, 175, '2026-11-24T10:02:00Z',
                    note: 'Consultation with Pt. Raghav Sharma: minute 3', astro: 'Pt. Raghav Sharma'),
                _t('3', TxnType.charge, -25, 200, '2026-11-24T10:01:00Z',
                    note: 'Consultation with Pt. Raghav Sharma: minute 2', astro: 'Pt. Raghav Sharma'),
                _t('2', TxnType.charge, -25, 225, '2026-11-24T10:00:00Z',
                    note: 'Consultation with Pt. Raghav Sharma: minute 1', astro: 'Pt. Raghav Sharma'),
                _t('1', TxnType.topup, 150, 250, '2026-11-23T08:00:00Z'),
                _t('0', TxnType.bonus, 100, 100, '2026-11-22T08:00:00Z'),
              ])),
        ],
      ));
}

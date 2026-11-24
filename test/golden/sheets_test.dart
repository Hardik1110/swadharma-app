import 'package:astro_connect/features/consultation/domain/consultation.dart';
import 'package:astro_connect/features/consultation/presentation/start_consultation.dart';
import 'package:astro_connect/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:astro_connect/features/wallet/presentation/widgets/top_up_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'harness.dart';

Widget _opener(void Function(BuildContext) open) => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(onPressed: () => open(context), child: const Text('open')),
        ),
      ),
    );

Future<void> _tapOpen(WidgetTester t) async {
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  for (final (name, balance) in [('confirm_sheet', 250), ('confirm_sheet_short', 5)]) {
    testWidgets(name, (t) => snapshot(
          t,
          name,
          _opener((c) => showConsultationConfirmSheet(
              c, sampleAstrologers()[2], ConsultationType.video)),
          overrides: [walletProvider.overrideWith(() => FakeWalletNotifier(balance: balance))],
          interact: _tapOpen,
        ));
  }

  testWidgets('top_up_sheet', (t) => snapshot(
        t,
        'top_up_sheet',
        _opener((c) => showTopUpSheet(c, needed: 45)),
        overrides: [walletProvider.overrideWith(() => FakeWalletNotifier(balance: 5))],
        interact: _tapOpen,
      ));
}

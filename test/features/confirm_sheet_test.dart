import 'package:astro_connect/core/theme/app_theme.dart';
import 'package:astro_connect/features/consultation/domain/consultation.dart';
import 'package:astro_connect/features/consultation/presentation/start_consultation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro_connect/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/load_fonts.dart';

import '../helpers.dart';

void main() {
  // Overflow errors fail the test, so this guards the "RenderFlex overflowed"
  // regression on small phones and with large accessibility text.
  for (final (label, size, scale) in [
    ('small phone', const Size(320, 568), 1.0),
    ('large text', const Size(390, 844), 1.6),
    ('small phone + large text', const Size(360, 640), 1.4),
  ]) {
    for (final type in ConsultationType.values) {
     for (final (walletLabel, balance, startKey) in [
       ('enough balance', 500, 'confirm_start'),
       ('short on balance', 5, 'add_money_to_start'),
     ]) {
      testWidgets('confirm sheet fits: $label / ${type.name} / $walletLabel', (tester) async {
        await loadAppFonts();
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(ProviderScope(
          overrides: [
            walletProvider.overrideWith(() => FakeWalletNotifier(balance: balance)),
          ],
          child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showConsultationConfirmSheet(
                    context,
                    sampleAstrologers()[2], // long name: "Acharya Vikram Joshi"
                    type,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        )));

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byKey(Key(startKey)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
     }
    }
  }
}

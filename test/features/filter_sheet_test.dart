import 'package:astro_connect/core/theme/app_theme.dart';
import 'package:astro_connect/features/astrologers/domain/astrologer.dart';
import 'package:astro_connect/features/astrologers/presentation/widgets/filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/load_fonts.dart';

void main() {
  for (final (label, size, scale) in [
    ('small phone', const Size(320, 568), 1.0),
    ('large text', const Size(390, 844), 1.6),
    ('small phone + large text', const Size(360, 640), 1.4),
    ('tablet', const Size(820, 1180), 1.0),
  ]) {
    testWidgets('filter sheet fits: $label', (tester) async {
      await loadAppFonts();
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showFilterSheet(
                  context,
                  initial: const AstrologerFilter(),
                  expertise: const [
                    'Vedic', 'Tarot', 'Numerology', 'Vastu', 'Palmistry', 'KP',
                    'Love & Relationship', 'Career', 'Face Reading',
                  ],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Apply filters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

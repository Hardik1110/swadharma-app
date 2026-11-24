import 'package:astro_connect/core/theme/app_theme.dart';
import 'package:astro_connect/features/consultation/domain/consultation.dart';
import 'package:astro_connect/features/consultation/presentation/start_consultation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/load_fonts.dart';
import '../helpers.dart';

void main() {
  Future<bool?> openDialog(WidgetTester tester, {required String tap}) async {
    await loadAppFonts();
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async => result = await showNotLiveDialog(
                context,
                sampleAstrologers().first,
                ConsultationType.video,
                'Pt. Raghav Sharma takes voice and video calls live and isn\'t '
                'available for them right now. You can start a chat instead.',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Video call unavailable'), findsOneWidget);
    expect(find.textContaining('start a chat instead'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(tap));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('"Chat instead" returns true', (tester) async {
    expect(await openDialog(tester, tap: 'Chat instead'), isTrue);
  });

  testWidgets('"Not now" returns false', (tester) async {
    expect(await openDialog(tester, tap: 'Not now'), isFalse);
  });
}

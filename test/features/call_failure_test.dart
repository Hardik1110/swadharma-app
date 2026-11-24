import 'package:astro_connect/core/theme/app_colors.dart';
import 'package:astro_connect/core/theme/app_theme.dart';
import 'package:astro_connect/features/consultation/domain/chat_message.dart';
import 'package:astro_connect/features/consultation/domain/consultation.dart';
import 'package:astro_connect/features/consultation/presentation/providers/call_controller.dart';
import 'package:astro_connect/features/consultation/presentation/providers/consultation_controller.dart';
import 'package:astro_connect/features/consultation/presentation/widgets/call_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/contrast_test.dart' show contrast;
import '../golden/load_fonts.dart';
import '../helpers.dart';

void main() {
  Future<(FakeCallController, List<String>)> pump(
    WidgetTester tester,
    CallState state,
  ) async {
    await loadAppFonts();
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final fake = FakeCallController('s1', state);
    final ended = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        callControllerProvider('s1').overrideWith(() => fake),
        viewerSenderProvider.overrideWithValue(MessageSender.user),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          backgroundColor: AppColors.indigoDeep, // what the consultation screen uses
          body: CallView(
            session: Consultation.fromJson(sessionJson(type: 'voice')),
            onEnd: (reason) async => ended.add(reason),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    return (fake, ended);
  }

  const failed = CallState(
    phase: CallPhase.failed,
    error: 'Could not connect the call. Check your internet connection.',
  );

  testWidgets('failure screen: message and both actions are visible', (tester) async {
    await pump(tester, failed);
    expect(find.text("The call couldn't connect"), findsOneWidget);
    expect(find.textContaining('Check your internet connection'), findsOneWidget);
    expect(find.byKey(const Key('call_retry')), findsOneWidget);
    expect(find.byKey(const Key('call_end_consultation')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failure screen buttons are readable on the dark backdrop', (tester) async {
    await pump(tester, failed);

    // The regression: "End consultation" was indigo on indigo, "Try again"
    // nearly invisible. Check the colours the buttons actually use.
    final end = tester.widget<OutlinedButton>(find.byKey(const Key('call_end_consultation')));
    final endText = end.style!.foregroundColor!.resolve({})!;
    expect(contrast(endText, AppColors.indigoDeep), greaterThanOrEqualTo(4.5),
        reason: 'End consultation text vs backdrop');
    final endBorder = end.style!.side!.resolve({})!.color;
    expect(contrast(endBorder, AppColors.indigoDeep), greaterThanOrEqualTo(3),
        reason: 'End consultation outline vs backdrop');

    final retry = tester.widget<FilledButton>(find.byKey(const Key('call_retry')));
    final retryBg = retry.style!.backgroundColor!.resolve({})!;
    final retryFg = retry.style!.foregroundColor!.resolve({})!;
    expect(contrast(retryBg, AppColors.indigoDeep), greaterThanOrEqualTo(3),
        reason: 'Try again fill vs backdrop');
    expect(contrast(retryFg, retryBg), greaterThanOrEqualTo(4.5),
        reason: 'Try again label vs its fill');
  });

  testWidgets('Try again joins again; End consultation reports a failed call', (tester) async {
    final (fake, ended) = await pump(tester, failed);
    final joinsBefore = fake.joins; // CallView auto-joins once on open

    await tester.tap(find.byKey(const Key('call_retry')));
    await tester.pump();
    expect(fake.joins, joinsBefore + 1);

    await tester.tap(find.byKey(const Key('call_end_consultation')));
    await tester.pump();
    expect(ended, ['call_failed']);
  });

  testWidgets('permission denied offers Open settings instead of Try again', (tester) async {
    await pump(
      tester,
      const CallState(
        phase: CallPhase.failed,
        error: 'Microphone access is needed for voice calls.',
        permissionDenied: true,
      ),
    );
    expect(find.byKey(const Key('call_settings')), findsOneWidget);
    expect(find.byKey(const Key('call_retry')), findsNothing);
    expect(find.byKey(const Key('call_end_consultation')), findsOneWidget);
  });

  testWidgets('connected call: the top bar sits at the top, clear of the avatar', (tester) async {
    await pump(tester, const CallState(phase: CallPhase.connected, remoteUid: 7));

    // Regression: the bar was centred vertically on top of the avatar.
    final bar = tester.getTopLeft(find.text('Voice call'));
    final name = tester.getTopLeft(find.text('Pt. Raghav Sharma'));
    expect(bar.dy, lessThan(80), reason: 'top bar is at the top of the screen');
    expect(bar.dy, lessThan(name.dy - 200), reason: 'and well above the astrologer\'s name');
    final controls = tester.getTopLeft(find.text('Mute'));
    expect(controls.dy, greaterThan(name.dy), reason: 'controls stay at the bottom');
  });
}

import 'package:astro_connect/core/theme/app_colors.dart';
import 'package:astro_connect/features/consultation/domain/chat_message.dart';
import 'package:astro_connect/features/consultation/domain/consultation.dart';
import 'package:astro_connect/features/consultation/presentation/providers/call_controller.dart';
import 'package:astro_connect/features/consultation/presentation/providers/consultation_controller.dart';
import 'package:astro_connect/features/consultation/presentation/widgets/call_view.dart';
import 'package:astro_connect/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'harness.dart';

Future<void> _shot(WidgetTester t, String name, CallState state, {String type = 'voice'}) =>
    snapshot(
      t,
      name,
      Scaffold(
        backgroundColor: AppColors.indigoDeep,
        body: CallView(
          session: Consultation.fromJson(sessionJson(type: type)),
          onEnd: (_) async {},
        ),
      ),
      overrides: [
        callControllerProvider('s1').overrideWith(() => FakeCallController('s1', state)),
        viewerSenderProvider.overrideWithValue(MessageSender.user),
        walletProvider.overrideWith(() => FakeWalletNotifier(balance: 10)),
      ],
    );

void main() {
  testWidgets('call_failed', (t) => _shot(t, 'call_failed', const CallState(
        phase: CallPhase.failed,
        error: 'Could not connect the call. Check your internet connection.',
      )));

  testWidgets('call_permission', (t) => _shot(t, 'call_permission', const CallState(
        phase: CallPhase.failed,
        error: 'Camera and microphone access are needed for video calls.',
        permissionDenied: true,
      ), type: 'video'));

  testWidgets('call_connected_low_balance', (t) => _shot(t, 'call_connected_low_balance',
      const CallState(phase: CallPhase.connected, remoteUid: 7)));
}

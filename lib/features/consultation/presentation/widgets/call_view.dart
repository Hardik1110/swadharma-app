import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/brand/brand.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../../domain/chat_message.dart';
import '../providers/consultation_controller.dart';
import '../../../wallet/presentation/widgets/top_up_sheet.dart';
import 'session_meter.dart';
import '../../domain/consultation.dart';
import '../providers/call_controller.dart';
import 'session_widgets.dart';

/// Full-screen voice/video call UI for an ongoing consultation.
class CallView extends ConsumerStatefulWidget {
  const CallView({super.key, required this.session, required this.onEnd});

  final Consultation session;

  /// Ends the consultation on the server; [reason] e.g. `call_failed`.
  final Future<void> Function(String reason) onEnd;

  @override
  ConsumerState<CallView> createState() => _CallViewState();
}

class _CallViewState extends ConsumerState<CallView> {
  bool get _video => widget.session.type == ConsultationType.video;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _join());
  }

  void _join() {
    final rtc = widget.session.rtc;
    if (rtc == null) return;
    ref.read(callControllerProvider(widget.session.id).notifier).join(rtc, video: _video);
  }

  Future<void> _end(String reason) async {
    if (_ending) return;
    setState(() => _ending = true);
    await ref.read(callControllerProvider(widget.session.id).notifier).leave();
    try {
      await widget.onEnd(reason);
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    if (s.rtc == null) {
      return _Failure(
        message: 'Calling is not configured on the server.',
        onEnd: () => _end('call_failed'),
      );
    }
    // The other person: the astrologer for a customer, the customer for an astrologer.
    final asAstrologer = ref.watch(viewerSenderProvider) == MessageSender.astrologer;
    final peerName = s.peerName(asAstrologer: asAstrologer);
    final peerAvatar = s.peerAvatar(asAstrologer: asAstrologer);
    final peerFirst = peerName.split(' ').where((p) => !p.endsWith('.')).firstOrNull ?? peerName;
    final call = ref.watch(callControllerProvider(s.id));
    final ctrl = ref.read(callControllerProvider(s.id).notifier);
    final engine = ctrl.engine;

    if (call.phase == CallPhase.failed) {
      return _Failure(
        message: call.error ?? 'The call failed.',
        onRetry: call.permissionDenied ? null : _join,
        onSettings: call.permissionDenied ? openAppSettings : null,
        onEnd: () => _end('call_failed'),
      );
    }

    final status = switch (call.phase) {
      CallPhase.idle || CallPhase.joining => 'Connecting…',
      CallPhase.reconnecting => 'Reconnecting…',
      _ when call.remoteLeft => '$peerFirst left the call',
      _ when !call.remoteJoined => 'Waiting for $peerFirst to join…',
      _ => null,
    };

    final showRemoteVideo =
        _video && engine != null && call.remoteJoined && call.remoteVideoOn;

    return ColoredBox(
      color: AppColors.indigoDeep,
      child: Stack(fit: StackFit.expand, children: [
        if (showRemoteVideo)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: engine,
              canvas: VideoCanvas(uid: call.remoteUid),
              connection: RtcConnection(channelId: ctrl.channel),
            ),
          )
        else
          HeroBackdrop(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold.withValues(alpha: .25), width: 1.4),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold.withValues(alpha: .4), width: 1.4),
                    ),
                    child: AppAvatar(
                        name: peerName, url: peerAvatar, size: 128, ring: true,
                        statusColor: AppColors.gold),
                  ),
                ),
                const SizedBox(height: 22),
                Text(peerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: AppTheme.serif,
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  status ?? (_video ? 'Camera is off' : 'On call'),
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ]),
            ),
          ),
        // Local preview
        if (_video && engine != null && call.phase != CallPhase.idle)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 64,
            right: 16,
            width: 110,
            height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: call.cameraOn
                  ? AgoraVideoView(
                      controller: VideoViewController(
                          rtcEngine: engine, canvas: const VideoCanvas(uid: 0)),
                    )
                  : const ColoredBox(
                      color: Colors.black54,
                      child: Center(
                          child: Icon(Icons.videocam_off_rounded, color: Colors.white70)),
                    ),
            ),
          ),
        // Top bar. Positioned: a bare SafeArea in an expanding Stack would
        // stretch to full height and centre the row mid-screen.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                Icon(s.type.icon, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text(s.type.label, style: const TextStyle(color: Colors.white70)),
                const Spacer(),
                if (!asAstrologer) ...[_CallBalance(session: s), const SizedBox(width: 8)],
                SessionTimerChip(seconds: () => s.elapsedSeconds, dark: true),
              ]),
            ),
          ),
        ),
        if (showRemoteVideo && status != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 64,
            left: 16,
            child: _Pill(status),
          ),
        // Controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _RoundButton(
                  key: const Key('call_mute'),
                  icon: call.micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: call.micMuted ? 'Unmute' : 'Mute',
                  active: call.micMuted,
                  onTap: ctrl.toggleMic,
                ),
                if (_video) ...[
                  _RoundButton(
                    key: const Key('call_camera'),
                    icon: call.cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    label: 'Camera',
                    active: !call.cameraOn,
                    onTap: ctrl.toggleCamera,
                  ),
                  _RoundButton(
                    icon: Icons.cameraswitch_rounded,
                    label: 'Flip',
                    onTap: call.cameraOn ? ctrl.switchCamera : null,
                  ),
                ],
                _RoundButton(
                  key: const Key('call_speaker'),
                  icon: call.speakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
                  label: call.speakerOn ? 'Speaker' : 'Earpiece',
                  active: call.speakerOn,
                  onTap: ctrl.toggleSpeaker,
                ),
                _RoundButton(
                  key: const Key('call_end'),
                  icon: Icons.call_end_rounded,
                  label: 'End',
                  color: Colors.redAccent,
                  onTap: _ending ? null : () => _end('user_ended'),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Live wallet balance in the call top bar; turns into a tappable warning
/// when the next minute can't be paid.
class _CallBalance extends ConsumerWidget {
  const _CallBalance({required this.session});

  final Consultation session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(walletProvider.select((w) => w.value?.balance));
    if (balance == null) return const SizedBox.shrink();
    final low = isBalanceLow(session, balance);
    return GestureDetector(
      key: const Key('call_balance'),
      onTap: low
          ? () => showTopUpSheet(context,
              needed: session.ratePerMinute * 5,
              reason: 'Add money to keep talking. Charges continue per minute.')
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: low ? AppColors.saffron : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(low ? Icons.warning_amber_rounded : Icons.account_balance_wallet_outlined,
              size: 15, color: low ? AppColors.onSaffron : Colors.white),
          const SizedBox(width: 5),
          Text(low ? 'Low · ${Fmt.money(balance)} · Add' : Fmt.money(balance),
              style: TextStyle(
                  color: low ? AppColors.onSaffron : Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? (active ? Colors.white : Colors.white24);
    final fg = color != null ? Colors.white : (active ? Colors.black87 : Colors.white);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Material(
        color: onTap == null ? bg.withValues(alpha: .4) : bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: 60, child: Icon(icon, color: fg, size: 28)),
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: Colors.white)),
      );
}

/// Shown when a call can't start or drops for good. It lives on the dark call
/// backdrop, so everything here is light-on-dark.
class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onEnd, this.onRetry, this.onSettings});

  final String message;
  final VoidCallback onEnd;
  final VoidCallback? onRetry;
  final Future<bool> Function()? onSettings;

  @override
  Widget build(BuildContext context) => HeroBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .1),
                    ),
                    child: const Icon(Icons.phone_disabled_rounded,
                        size: 44, color: AppColors.gold),
                  ),
                  const SizedBox(height: 22),
                  const Text("The call couldn't connect",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.serif,
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 10),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .75), fontSize: 15, height: 1.4)),
                  const SizedBox(height: 28),
                  if (onRetry != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('call_retry'),
                        onPressed: onRetry,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.saffron,
                          foregroundColor: AppColors.onSaffron,
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ),
                  if (onSettings != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('call_settings'),
                        onPressed: onSettings,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.saffron,
                          foregroundColor: AppColors.onSaffron,
                        ),
                        icon: const Icon(Icons.settings_rounded),
                        label: const Text('Open settings'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const Key('call_end_consultation'),
                      onPressed: onEnd,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54, width: 1.4),
                      ),
                      child: const Text('End consultation'),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/realtime_providers.dart';
import '../../../../core/network/socket_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';

/// Rebuilds every second with a value computed by [seconds].
class TickingText extends StatefulWidget {
  const TickingText({super.key, required this.seconds, this.style, this.format = Fmt.clock});

  final int Function() seconds;
  final String Function(int) format;
  final TextStyle? style;

  @override
  State<TickingText> createState() => _TickingTextState();
}

class _TickingTextState extends State<TickingText> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        widget.format(widget.seconds()),
        style: widget.style,
        key: const Key('session_timer'),
      );
}

/// Pill showing the running consultation time.
class SessionTimerChip extends StatelessWidget {
  const SessionTimerChip({super.key, required this.seconds, this.dark = false});

  final int Function() seconds;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.indigo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: dark ? Colors.white24 : AppColors.lavender,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_outlined, size: 16, color: fg),
        const SizedBox(width: 4),
        TickingText(
          seconds: seconds,
          style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ]),
    );
  }
}

/// Banner shown while the realtime connection is down. [floating] renders a
/// rounded pill that overlays full-screen (dark) states.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key, this.floating = false});

  final bool floating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(socketStatusProvider);
    final show = status != SocketStatus.connected;
    final content = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox.square(
          dimension: 12,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger)),
      const SizedBox(width: 10),
      const Text('Connection lost. Reconnecting…',
          style: TextStyle(color: Color(0xFF7A1F2B), fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: !show
          ? const SizedBox(width: double.infinity)
          : floating
              ? Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14)],
                  ),
                  child: content,
                )
              : Container(
                  width: double.infinity,
                  color: const Color(0xFFFCE4E7),
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
                  child: content,
                ),
    );
  }
}

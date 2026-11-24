import 'package:flutter/material.dart';

import '../../../../core/brand/brand.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../domain/consultation.dart';
import 'session_widgets.dart';

/// Full-screen "waiting for the astrologer to accept" state.
class WaitingView extends StatefulWidget {
  const WaitingView({
    super.key,
    required this.session,
    required this.onCancel,
    required this.onClose,
  });

  final Consultation session;
  final Future<void> Function() onCancel;
  final VoidCallback onClose;

  @override
  State<WaitingView> createState() => _WaitingViewState();
}

class _WaitingViewState extends State<WaitingView> with SingleTickerProviderStateMixin {
  late final _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  bool _cancelling = false;

  static const _timeout = 60;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final theme = Theme.of(context);
    final first = s.astrologerName.split(' ').where((p) => !p.endsWith('.')).firstOrNull ??
        s.astrologerName;

    return HeroBackdrop(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.white12),
              ),
            ),
            const Spacer(),
            SizedBox.square(
              dimension: 260,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) => Stack(alignment: Alignment.center, children: [
                  for (final offset in [0.0, .33, .66])
                    () {
                      final t = (_pulse.value + offset) % 1;
                      return Container(
                        width: 130 + 130 * t,
                        height: 130 + 130 * t,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: (1 - t) * .55),
                            width: 1.6,
                          ),
                        ),
                      );
                    }(),
                  child!,
                ]),
                child: AppAvatar(name: s.astrologerName, url: s.astrologerAvatar, size: 124, ring: true,
                    statusColor: AppColors.gold),
              ),
            ),
            const SizedBox(height: 18),
            Text('Connecting you with',
                style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 14, letterSpacing: .3)),
            const SizedBox(height: 6),
            Text(s.astrologerName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.serif,
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(s.type.icon, size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                Text('${s.type.label} · ${Fmt.perMinute(s.ratePerMinute)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 22),
            TickingText(
              seconds: () => (_timeout - s.waitingSeconds).clamp(0, _timeout),
              format: (v) => v > 0
                  ? '$first usually responds within ${v}s'
                  : 'Still waiting for $first…',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const Spacer(),
            Text(
              'Keep this screen open. Your session starts the moment $first accepts.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('cancel_request'),
                onPressed: _cancelling
                    ? null
                    : () async {
                        setState(() => _cancelling = true);
                        try {
                          await widget.onCancel();
                        } finally {
                          if (mounted) setState(() => _cancelling = false);
                        }
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38, width: 1.4),
                  minimumSize: const Size(64, 54),
                ),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cancel request'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

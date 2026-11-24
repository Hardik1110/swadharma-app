import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/async_views.dart';
import '../../../../core/widgets/ui.dart';
import '../../domain/consultation.dart';
import 'birth_details.dart';
import 'session_widgets.dart';

/// What the astrologer sees when they open a pending request: who is asking,
/// their birth details, and Accept / Decline.
class IncomingRequestView extends StatefulWidget {
  const IncomingRequestView({
    super.key,
    required this.session,
    required this.onAccept,
    required this.onDecline,
  });

  final Consultation session;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  @override
  State<IncomingRequestView> createState() => _IncomingRequestViewState();
}

class _IncomingRequestViewState extends State<IncomingRequestView> {
  bool _busy = false;

  static const _timeout = 60;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
        MaxWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SoftCard(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                AppAvatar(name: s.userName, size: 72, ring: true),
                const SizedBox(height: 14),
                Text(s.userName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: AppTheme.serif, fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('would like a ${s.type.label.toLowerCase()}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Pill(icon: s.type.icon, label: s.type.label, color: AppColors.indigo),
                  const SizedBox(width: 8),
                  Pill(label: Fmt.perMinute(s.ratePerMinute), color: AppColors.saffron),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            SoftCard(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Birth details', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                BirthDetails(session: s),
              ]),
            ),
            const SizedBox(height: 16),
            Center(
              child: TickingText(
                seconds: () => (_timeout - s.waitingSeconds).clamp(0, _timeout),
                format: (v) =>
                    v > 0 ? 'Respond within ${Fmt.clock(v)}' : 'This request is about to expire',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              key: const Key('accept_request'),
              label: s.type.isCall ? 'Accept and join ${s.type.label.toLowerCase()}' : 'Accept and start chat',
              icon: s.type.icon,
              loading: _busy,
              onPressed: () => _run(widget.onAccept),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('decline_request'),
              onPressed: _busy ? null : () => _run(widget.onDecline),
              child: const Text('Decline'),
            ),
          ]),
        ),
      ]),
    );
  }
}

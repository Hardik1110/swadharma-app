import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/async_views.dart';
import '../../../../core/widgets/ui.dart';
import '../../../consultation/domain/consultation.dart';
import '../../../consultation/presentation/widgets/birth_details.dart';
import '../../../consultation/presentation/widgets/session_widgets.dart';
import '../providers/desk_providers.dart';

/// An incoming consultation request with Accept / Decline.
class RequestCard extends ConsumerStatefulWidget {
  const RequestCard({super.key, required this.session});

  final Consultation session;

  @override
  ConsumerState<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<RequestCard> {
  bool _busy = false;

  static const _timeout = 60;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      final session = await ref.read(requestActionsProvider).accept(widget.session.id);
      if (mounted) context.push(Routes.consultation(session.id));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await ref.read(requestActionsProvider).decline(widget.session.id);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final theme = Theme.of(context);
    return SoftCard(
      key: Key('request_${s.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          AppAvatar(name: s.userName, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: AppTheme.serif, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(children: [
                Pill(icon: s.type.icon, label: s.type.label, color: AppColors.indigo, dense: true),
                const SizedBox(width: 8),
                Text(Fmt.perMinute(s.ratePerMinute), style: theme.textTheme.bodySmall),
              ]),
            ]),
          ),
          TickingText(
            seconds: () => (_timeout - s.waitingSeconds).clamp(0, _timeout),
            format: (v) => '${Fmt.clock(v)} left',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: s.waitingSeconds > 45 ? AppColors.danger : AppColors.muted,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.ivory,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.auto_awesome_outlined, size: 18, color: AppColors.indigo),
            const SizedBox(width: 10),
            Expanded(child: BirthDetails(session: s, compact: true)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            flex: 2,
            child: OutlinedButton(
              key: Key('decline_${s.id}'),
              onPressed: _busy ? null : _decline,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 50),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Decline', maxLines: 1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: PrimaryButton(
              key: Key('accept_${s.id}'),
              label: 'Accept',
              icon: Icons.check_rounded,
              height: 50,
              loading: _busy,
              onPressed: _accept,
            ),
          ),
        ]),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/async_views.dart';
import '../../../../core/widgets/ui.dart';
import '../../../astrologers/domain/astrologer.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../consultation/domain/consultation.dart';
import '../../../consultation/presentation/providers/consultation_controller.dart';
import '../../../consultation/presentation/widgets/session_widgets.dart';
import '../../domain/desk.dart';
import '../providers/desk_providers.dart';
import '../widgets/request_card.dart';

/// Home of the astrologer app: availability, today's numbers, live requests.
class DeskDashboardPage extends ConsumerWidget {
  const DeskDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final profile = ref.watch(deskProfileProvider);
    final history = ref.watch(consultationHistoryProvider);
    final pending = ref.watch(pendingRequestsProvider);
    final ongoing = (history.value ?? const <Consultation>[])
        .where((c) => c.status == ConsultationStatus.ongoing)
        .firstOrNull;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.indigo,
          onRefresh: () async {
            ref.invalidate(consultationHistoryProvider);
            ref.invalidate(deskProfileProvider);
            await ref.read(deskProfileProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              MaxWidth(
                maxWidth: 720,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Namaste 🙏',
                            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                        const SizedBox(height: 2),
                        Text(user?.name ?? 'Astrologer',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineMedium),
                      ]),
                    ),
                    GestureDetector(
                      onTap: () => context.go(Routes.deskProfile),
                      child: AppAvatar(
                          name: user?.name ?? '', url: user?.avatarUrl, size: 46, ring: true),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  profile.when(
                    skipLoadingOnReload: true,
                    skipLoadingOnRefresh: true,
                    loading: () => const SizedBox(height: 96, child: LoadingView()),
                    error: (e, _) => SoftCard(
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                        const SizedBox(width: 12),
                        Expanded(child: Text(AppException.from(e).message)),
                        TextButton(
                            onPressed: () => ref.invalidate(deskProfileProvider),
                            child: const Text('Retry')),
                      ]),
                    ),
                    data: (p) => Column(children: [
                      AvailabilityCard(profile: p),
                      const SizedBox(height: 16),
                      _StatsRow(stats: p.stats),
                    ]),
                  ),
                  if (ongoing != null) ...[
                    const SizedBox(height: 22),
                    _ActiveCard(session: ongoing),
                  ],
                  const SizedBox(height: 26),
                  SectionTitle(
                    'Requests',
                    trailing: pending.isEmpty
                        ? null
                        : Pill(label: '${pending.length} waiting', color: AppColors.saffron),
                  ),
                  const SizedBox(height: 12),
                  history.when(
                    skipLoadingOnReload: true,
                    skipLoadingOnRefresh: true,
                    loading: () => const SizedBox(height: 120, child: LoadingView()),
                    error: (e, _) => ErrorView(
                        error: e, onRetry: () => ref.invalidate(consultationHistoryProvider)),
                    data: (_) => pending.isEmpty
                        ? _NoRequests(offline: profile.value?.isAvailable == false)
                        : Column(children: [
                            for (final r in pending)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: RequestCard(session: r),
                              ),
                          ]),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AvailabilityCard extends ConsumerStatefulWidget {
  const AvailabilityCard({super.key, required this.profile});

  final DeskProfile profile;

  @override
  ConsumerState<AvailabilityCard> createState() => _AvailabilityCardState();
}

class _AvailabilityCardState extends ConsumerState<AvailabilityCard> {
  bool _saving = false;

  Future<void> _toggle(bool online) async {
    setState(() => _saving = true);
    try {
      await ref.read(requestActionsProvider).setOnline(online);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.profile.astrologer.status;
    final busy = status == AstrologerStatus.busy;
    final online = status != AstrologerStatus.offline;
    final color = busy ? AppColors.busy : online ? AppColors.success : AppColors.offline;
    final title = busy ? 'In a consultation' : online ? 'You are online' : 'You are offline';
    final subtitle = busy
        ? 'Finish this consultation to change availability'
        : online
            ? 'Customers can request chats, calls and video'
            : 'Go online to start receiving requests';

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
          child: Icon(
              busy
                  ? Icons.hourglass_top_rounded
                  : online
                      ? Icons.radio_button_checked_rounded
                      : Icons.bedtime_outlined,
              color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        Switch(
          key: const Key('availability_switch'),
          value: online,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.success,
          onChanged: busy || _saving ? null : _toggle,
        ),
      ]),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final DeskStats stats;

  @override
  Widget build(BuildContext context) {
    Widget tile(String value, String label, {bool accent = false}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              gradient: accent ? AppColors.heroGradient : null,
              color: accent ? null : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: accent ? null : Border.all(color: AppColors.hairline),
            ),
            child: Column(children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: accent ? Colors.white : AppColors.ink)),
              const SizedBox(height: 3),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: accent ? Colors.white70 : AppColors.muted)),
            ]),
          ),
        );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        tile(Fmt.money(stats.todayEarnings), 'earned today', accent: true),
        const SizedBox(width: 10),
        tile('${stats.todayConsultations}', 'sessions today'),
        const SizedBox(width: 10),
        tile(Fmt.money(stats.totalEarnings), 'total earned'),
      ]),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.session});

  final Consultation session;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppColors.indigo.withValues(alpha: .28),
                blurRadius: 18,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const Key('active_consultation'),
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push(Routes.consultation(session.id)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                AppAvatar(name: session.userName, size: 46, ring: true, statusColor: AppColors.success),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${session.type.label} with ${session.userName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5)),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.timer_outlined, size: 15, color: Colors.white70),
                      const SizedBox(width: 4),
                      TickingText(
                        seconds: () => session.elapsedSeconds,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text('  ·  earning ${Fmt.money(session.earning)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppColors.saffron, borderRadius: BorderRadius.circular(14)),
                  child: const Text('Open',
                      style: TextStyle(color: AppColors.onSaffron, fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _NoRequests extends StatelessWidget {
  const _NoRequests({required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle),
            child: Icon(offline ? Icons.bedtime_outlined : Icons.notifications_none_rounded,
                color: AppColors.indigo, size: 30),
          ),
          const SizedBox(height: 14),
          Text(offline ? 'You are offline' : 'No requests right now',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            offline
                ? 'Go online above to start receiving consultation requests.'
                : 'Stay on this screen. New requests appear here the moment a customer asks for you.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ]),
      );
}

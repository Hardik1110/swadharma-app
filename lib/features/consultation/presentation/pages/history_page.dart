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
import '../../domain/chat_message.dart';
import '../../domain/consultation.dart';
import '../providers/consultation_controller.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(consultationHistoryProvider);
    final asAstrologer = ref.watch(viewerSenderProvider) == MessageSender.astrologer;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your consultations'),
        titleSpacing: 20,
      ),
      body: RefreshIndicator(
        color: AppColors.indigo,
        onRefresh: () => ref.refresh(consultationHistoryProvider.future),
        child: history.when(
          skipLoadingOnRefresh: true,
          loading: () => const LoadingView(),
          error: (e, _) => ListView(children: [
            SizedBox(
              height: 400,
              child: ErrorView(
                  error: e, onRetry: () => ref.invalidate(consultationHistoryProvider)),
            ),
          ]),
          data: (items) => items.isEmpty
              ? ListView(children: [
                  SizedBox(
                    height: 460,
                    child: EmptyView(
                      icon: Icons.forum_outlined,
                      title: 'No consultations yet',
                      subtitle: asAstrologer
                          ? 'Requests you accept will appear here.'
                          : 'Your chats and calls with astrologers will appear here.',
                      action: asAstrologer
                          ? null
                          : SizedBox(
                              width: 240,
                              child: PrimaryButton(
                                label: 'Find an astrologer',
                                onPressed: () => context.go(Routes.astrologers),
                              ),
                            ),
                    ),
                  ),
                ])
              : _List(items: items, asAstrologer: asAstrologer),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.items, required this.asAstrologer});

  final List<Consultation> items;
  final bool asAstrologer;

  @override
  Widget build(BuildContext context) {
    final completed = items.where((c) => c.status == ConsultationStatus.completed);
    final minutes = completed.fold<int>(0, (s, c) => s + c.durationSeconds) ~/ 60;
    final money = completed.fold<int>(0, (s, c) => s + (asAstrologer ? c.earning : c.cost));

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i == 0) {
          return MaxWidth(
            maxWidth: 720,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.indigo.withValues(alpha: .3),
                      blurRadius: 22,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: IntrinsicHeight(
                child: Row(children: [
                  _Stat('${completed.length}', 'completed'),
                  const VerticalDivider(color: Colors.white24, width: 1),
                  _Stat('$minutes', 'minutes'),
                  const VerticalDivider(color: Colors.white24, width: 1),
                  _Stat(Fmt.money(money), asAstrologer ? 'earned' : 'spent'),
                ]),
              ),
            ),
          );
        }
        return MaxWidth(maxWidth: 720, child: _Tile(items[i - 1], asAstrologer: asAstrologer));
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 13)),
        ]),
      );
}

class _Tile extends StatelessWidget {
  const _Tile(this.c, {required this.asAstrologer});
  final Consultation c;
  final bool asAstrologer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (c.status) {
      ConsultationStatus.completed => AppColors.success,
      ConsultationStatus.ongoing || ConsultationStatus.requested => AppColors.indigo,
      ConsultationStatus.cancelled => AppColors.offline,
      _ => AppColors.busy,
    };

    return SoftCard(
      onTap: () => context.push(Routes.consultation(c.id)),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          AppAvatar(
              name: c.peerName(asAstrologer: asAstrologer),
              url: c.peerAvatar(asAstrologer: asAstrologer),
              size: 52),
          Positioned(
            right: -5,
            bottom: -5,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.hairline),
              ),
              child: Icon(c.type.icon, size: 13, color: AppColors.indigo),
            ),
          ),
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.peerName(asAstrologer: asAstrologer),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: AppTheme.serif, fontSize: 16.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              [
                Fmt.shortDateTime(c.requestedAt),
                if (c.status == ConsultationStatus.completed) Fmt.duration(c.durationSeconds),
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            if (c.lastMessageText != null && c.type == ConsultationType.chat) ...[
              const SizedBox(height: 3),
              Text(c.lastMessageText!,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Pill(label: c.status.label, color: color, dense: true),
          if (c.status == ConsultationStatus.completed) ...[
            const SizedBox(height: 8),
            Text(asAstrologer ? '+${Fmt.money(c.earning)}' : Fmt.money(c.cost),
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: asAstrologer ? AppColors.success : AppColors.ink)),
          ],
        ]),
      ]),
    );
  }
}

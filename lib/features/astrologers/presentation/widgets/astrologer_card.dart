import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/ui.dart';
import '../../../consultation/domain/consultation.dart';
import '../../../consultation/presentation/start_consultation.dart';
import '../../domain/astrologer.dart';
import '../providers/astrologer_providers.dart';

Color statusColor(AstrologerStatus s) => switch (s) {
      AstrologerStatus.online => AppColors.success,
      AstrologerStatus.busy => AppColors.busy,
      AstrologerStatus.offline => AppColors.offline,
    };

/// 4.3k style count.
String compactCount(int n) {
  if (n < 1000) return '$n';
  final v = (n / 1000).toStringAsFixed(1);
  return '${v.endsWith('.0') ? v.substring(0, v.length - 2) : v}k';
}

class AstrologerCard extends ConsumerWidget {
  const AstrologerCard({super.key, required this.astrologer, required this.onTap});

  final Astrologer astrologer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = astrologer;
    final status = ref.watch(presenceProvider.select((m) => m[a.id])) ?? a.status;
    final callsEnabled = ref.watch(appConfigProvider).value?.callsEnabled ?? false;
    final theme = Theme.of(context);
    final online = status == AstrologerStatus.online;

    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Hero(
            tag: 'avatar-${a.id}',
            child: AppAvatar(
                name: a.name,
                url: a.avatarUrl,
                size: 74,
                ring: true,
                statusColor: statusColor(status)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: AppTheme.serif,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.2)),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.verified_rounded, size: 17, color: AppColors.violet),
              ]),
              const SizedBox(height: 4),
              Text(a.expertise.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.indigo, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(a.languages.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.star_rounded, size: 17, color: AppColors.gold),
                const SizedBox(width: 3),
                Text(a.rating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(' (${compactCount(a.ratingCount)})', style: theme.textTheme.bodySmall),
                const SizedBox(width: 10),
                Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.offline, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text('${a.experienceYears} yrs exp', style: theme.textTheme.bodySmall),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 10),
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(Fmt.money(a.chatPrice),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.1)),
            const Text('per minute',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.3)),
          ]),
          const Spacer(),
          if (online) ...[
            if (callsEnabled) ...[
              _RoundAction(
                icon: Icons.call_rounded,
                tooltip: 'Voice call ${Fmt.perMinute(a.pricing['voice'] ?? 0)}',
                onTap: () => startConsultation(context, ref, a, ConsultationType.voice),
              ),
              const SizedBox(width: 8),
              _RoundAction(
                icon: Icons.videocam_rounded,
                tooltip: 'Video call ${Fmt.perMinute(a.pricing['video'] ?? 0)}',
                onTap: () => startConsultation(context, ref, a, ConsultationType.video),
              ),
              const SizedBox(width: 10),
            ],
            _ChatButton(onTap: () => startConsultation(context, ref, a, ConsultationType.chat)),
          ] else
            Pill(
              icon: status == AstrologerStatus.busy
                  ? Icons.hourglass_top_rounded
                  : Icons.bedtime_outlined,
              label: status == AstrologerStatus.busy ? 'In a session' : 'Offline',
              color: statusColor(status),
            ),
        ]),
      ]),
    );
  }
}

class _ChatButton extends StatelessWidget {
  const _ChatButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: AppColors.ctaGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                SizedBox(width: 7),
                Text('Chat',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
            ),
          ),
        ),
      );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: AppColors.lavender,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: 40,
              child: Icon(icon, size: 19, color: AppColors.indigo),
            ),
          ),
        ),
      );
}

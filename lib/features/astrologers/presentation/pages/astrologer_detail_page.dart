import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/brand/brand.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/async_views.dart';
import '../../../../core/widgets/ui.dart';
import '../../../consultation/domain/consultation.dart';
import '../../../consultation/presentation/start_consultation.dart';
import '../../domain/astrologer.dart';
import '../providers/astrologer_providers.dart';
import '../widgets/astrologer_card.dart';

class AstrologerDetailPage extends ConsumerWidget {
  const AstrologerDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(astrologerDetailProvider(id));
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: detail.when(
        loading: () => Stack(children: [
          const Positioned.fill(child: LoadingView()),
          const _BackButton(),
        ]),
        error: (e, _) => Stack(children: [
          Positioned.fill(
            child: ErrorView(
                error: e, onRetry: () => ref.invalidate(astrologerDetailProvider(id))),
          ),
          const _BackButton(dark: true),
        ]),
        data: (a) => _Body(astrologer: a),
      ),
      bottomNavigationBar: detail.whenOrNull(data: (a) => _ActionBar(astrologer: a)),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: dark ? AppColors.lavender : Colors.white24,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.canPop() ? context.pop() : context.go('/astrologers'),
              child: SizedBox.square(
                dimension: 42,
                child: Icon(Icons.arrow_back_rounded,
                    color: dark ? AppColors.ink : Colors.white),
              ),
            ),
          ),
        ),
      );
}

class _Body extends ConsumerWidget {
  const _Body({required this.astrologer});

  final Astrologer astrologer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = astrologer;
    final status = ref.watch(presenceProvider.select((m) => m[a.id])) ?? a.status;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(astrologerDetailProvider(a.id).future),
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Hero header with overlapping stats card.
          Stack(clipBehavior: Clip.none, children: [
            HeroBackdrop(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 62),
                  child: Column(children: [
                    Hero(
                      tag: 'avatar-${a.id}',
                      child: AppAvatar(
                          name: a.name,
                          url: a.avatarUrl,
                          size: 112,
                          ring: true,
                          statusColor: statusColor(status)),
                    ),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Flexible(
                        child: Text(a.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: AppTheme.serif,
                              fontSize: 26,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            )),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded, size: 22, color: AppColors.gold),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in a.expertise)
                          Pill(
                            label: e,
                            color: Colors.white,
                            background: Colors.white.withValues(alpha: .14),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: status == AstrologerStatus.offline
                                  ? AppColors.offline
                                  : statusColor(status),
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status == AstrologerStatus.online
                              ? 'Available now'
                              : status == AstrologerStatus.busy
                                  ? 'In a session'
                                  : 'Offline',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
            const _BackButton(),
            Positioned(
              left: 20,
              right: 20,
              bottom: -40,
              child: SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: IntrinsicHeight(
                  child: Row(children: [
                    _Stat(
                      value: a.rating.toStringAsFixed(1),
                      label: '${compactCount(a.ratingCount)} ratings',
                      icon: Icons.star_rounded,
                      iconColor: AppColors.gold,
                    ),
                    const VerticalDivider(width: 1),
                    _Stat(value: '${a.experienceYears} yrs', label: 'experience'),
                    const VerticalDivider(width: 1),
                    _Stat(value: compactCount(a.totalConsultations), label: 'consultations'),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 64),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('About'),
              const SizedBox(height: 10),
              Text(a.bio, style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)),
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.translate_rounded, size: 18, color: AppColors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Speaks ${a.languages.join(', ')}',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 26),
              const SectionTitle('Consultation charges'),
              const SizedBox(height: 12),
              Row(children: [
                for (final t in ConsultationType.values) ...[
                  if (t != ConsultationType.chat) const SizedBox(width: 12),
                  Expanded(child: _PriceTile(type: t, price: a.pricing[t.name] ?? 0)),
                ],
              ]),
              const SizedBox(height: 28),
              SectionTitle('Reviews',
                  trailing: Text('${a.reviews.length} shown', style: theme.textTheme.bodySmall)),
              const SizedBox(height: 12),
              if (a.reviews.isEmpty)
                SoftCard(
                  child: Center(
                    child: Text('No reviews yet. Be the first to share your experience.',
                        textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  ),
                )
              else
                for (final r in a.reviews)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReviewCard(review: r),
                  ),
              const SizedBox(height: 12),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.icon, this.iconColor});

  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 20, color: iconColor), const SizedBox(width: 3)],
            Text(value,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ]),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

class _PriceTile extends StatelessWidget {
  const _PriceTile({required this.type, required this.price});

  final ConsultationType type;
  final int price;

  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle),
            child: Icon(type.icon, size: 21, color: AppColors.indigo),
          ),
          const SizedBox(height: 10),
          Text(type == ConsultationType.chat ? 'Chat' : type == ConsultationType.voice ? 'Voice' : 'Video',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(Fmt.money(price),
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.indigo)),
          const Text('per min', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ]),
      );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AppAvatar(name: review.userName, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(review.userName, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(Fmt.date(review.createdAt), style: theme.textTheme.bodySmall),
            ]),
          ),
          RatingStars(rating: review.rating.toDouble(), size: 16),
        ]),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(review.comment, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        ],
      ]),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.astrologer});

  final Astrologer astrologer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = astrologer;
    final status = ref.watch(presenceProvider.select((m) => m[a.id])) ?? a.status;
    final callsEnabled = ref.watch(appConfigProvider).value?.callsEnabled ?? false;
    final available = status == AstrologerStatus.online;
    final first = a.name.split(' ').where((p) => !p.endsWith('.')).firstOrNull ?? a.name;

    String? note;
    if (!available) {
      note = status == AstrologerStatus.busy
          ? '$first is in another consultation. Please try again shortly.'
          : '$first is offline right now.';
    } else if (!callsEnabled) {
      note = 'Voice and video calls are not enabled on this server.';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: AppColors.indigo.withValues(alpha: .10),
              blurRadius: 24,
              offset: const Offset(0, -6)),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Flexible(child: Text(note, style: Theme.of(context).textTheme.bodySmall)),
                ]),
              ),
            Row(children: [
              for (final t in ConsultationType.values) ...[
                if (t != ConsultationType.chat) const SizedBox(width: 10),
                Expanded(
                  child: _OptionButton(
                    key: Key('start_${t.name}'),
                    type: t,
                    price: a.pricing[t.name] ?? 0,
                    primary: t == ConsultationType.chat,
                    enabled: available && (t == ConsultationType.chat || callsEnabled),
                    onTap: () => startConsultation(context, ref, a, t),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    super.key,
    required this.type,
    required this.price,
    required this.primary,
    required this.enabled,
    required this.onTap,
  });

  final ConsultationType type;
  final int price;
  final bool primary;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled ? AppColors.offline : primary ? Colors.white : AppColors.indigo;
    final label = type == ConsultationType.chat ? 'Chat' : type == ConsultationType.voice ? 'Call' : 'Video';
    return Opacity(
      opacity: enabled ? 1 : .55,
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          gradient: primary && enabled ? AppColors.ctaGradient : null,
          color: primary && enabled ? null : AppColors.lavender,
          borderRadius: BorderRadius.circular(18),
          boxShadow: primary && enabled
              ? [
                  BoxShadow(
                      color: AppColors.indigo.withValues(alpha: .3),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onTap : null,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(type.icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15)),
              ]),
              const SizedBox(height: 3),
              Text('${Fmt.money(price)}/min',
                  style: TextStyle(
                      color: fg.withValues(alpha: primary ? .85 : .75),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

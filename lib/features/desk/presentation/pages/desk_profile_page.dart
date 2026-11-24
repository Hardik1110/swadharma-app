import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/brand/brand.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/async_views.dart';
import '../../../../core/widgets/ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../consultation/domain/consultation.dart';
import '../providers/desk_providers.dart';

/// The astrologer's own profile (as customers see it) plus logout.
class DeskProfilePage extends ConsumerWidget {
  const DeskProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final profile = ref.watch(deskProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: profile.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(deskProfileProvider)),
        data: (p) {
          final a = p.astrologer;
          return ListView(padding: EdgeInsets.zero, children: [
            HeroBackdrop(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 56),
                  child: Column(children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Your profile',
                          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white70)),
                    ),
                    const SizedBox(height: 14),
                    AppAvatar(name: a.name, url: a.avatarUrl, size: 92, ring: true, statusColor: AppColors.gold),
                    const SizedBox(height: 14),
                    Text(a.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: AppTheme.serif,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(user == null ? '' : Fmt.phone(user.phone),
                        style: TextStyle(color: Colors.white.withValues(alpha: .7))),
                    const SizedBox(height: 12),
                    Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                      for (final e in a.expertise)
                        Pill(
                            label: e,
                            color: Colors.white,
                            background: Colors.white.withValues(alpha: .14)),
                    ]),
                  ]),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: MaxWidth(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: IntrinsicHeight(
                        child: Row(children: [
                          _Stat('${a.rating.toStringAsFixed(1)} ★', '${a.ratingCount} ratings'),
                          const VerticalDivider(width: 1),
                          _Stat('${a.experienceYears} yrs', 'experience'),
                          const VerticalDivider(width: 1),
                          _Stat('${p.stats.totalConsultations}', 'completed'),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SoftCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Your rates', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 10),
                        for (final t in ConsultationType.values)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(children: [
                              Icon(t.icon, size: 20, color: AppColors.indigo),
                              const SizedBox(width: 12),
                              Expanded(child: Text(t.label)),
                              Text(Fmt.perMinute(a.pricing[t.name] ?? 0),
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        const Divider(height: 22),
                        Text(
                          'You keep ${(p.stats.share * 100).round()}% of every charge.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: InkWell(
                        key: const Key('desk_logout'),
                        onTap: () async {
                          final ok = await confirm(context,
                              title: 'Log out?',
                              message: 'You will stop receiving consultation requests.',
                              confirmLabel: 'Log out',
                              destructive: true);
                          if (ok) await ref.read(authProvider.notifier).logout();
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(children: [
                            Icon(Icons.logout_rounded, color: AppColors.danger),
                            SizedBox(width: 14),
                            Text('Log out',
                                style: TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15.5)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Center(child: BrandLockup(markSize: 26, light: false)),
                    const SizedBox(height: 4),
                    Center(child: Text('Astrologer app', style: theme.textTheme.bodySmall)),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

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
import '../../../../core/brand/brand.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final sign = user.sunSign;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(clipBehavior: Clip.none, children: [
            HeroBackdrop(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 60),
                  child: Column(children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Profile',
                          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white70)),
                    ),
                    const SizedBox(height: 14),
                    AppAvatar(name: user.name, size: 92, ring: true, statusColor: AppColors.gold),
                    const SizedBox(height: 14),
                    Text(user.displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppTheme.serif,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                    const SizedBox(height: 4),
                    Text(Fmt.phone(user.phone),
                        style: TextStyle(color: Colors.white.withValues(alpha: .7))),
                    if (sign != null) ...[
                      const SizedBox(height: 12),
                      Pill(
                        icon: Icons.wb_sunny_outlined,
                        label: '$sign sun sign',
                        color: AppColors.gold,
                        background: Colors.white.withValues(alpha: .12),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ]),
          Transform.translate(
            offset: const Offset(0, -34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: MaxWidth(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SoftCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(children: [
                      _InfoRow(Icons.cake_outlined, 'Date of birth',
                          user.dobDate == null ? '-' : Fmt.date(user.dobDate!)),
                      const Divider(indent: 64),
                      _InfoRow(Icons.schedule_rounded, 'Birth time', Fmt.birthTime(user.birthTime)),
                      const Divider(indent: 64),
                      _InfoRow(Icons.place_outlined, 'Birth place', user.birthPlace),
                      if (user.gender.isNotEmpty) ...[
                        const Divider(indent: 64),
                        _InfoRow(Icons.wc_rounded, 'Gender', user.gender),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 16),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(children: [
                      _ActionRow(
                        icon: Icons.edit_outlined,
                        label: 'Edit profile',
                        onTap: () => context.push(Routes.editProfile),
                      ),
                      const Divider(indent: 64),
                      _ActionRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Wallet',
                        onTap: () => context.push(Routes.wallet),
                      ),
                      const Divider(indent: 64),
                      _ActionRow(
                        icon: Icons.history_rounded,
                        label: 'Consultation history',
                        onTap: () => context.go(Routes.history),
                      ),
                      const Divider(indent: 64),
                      _ActionRow(
                        icon: Icons.logout_rounded,
                        label: 'Log out',
                        danger: true,
                        onTap: () async {
                          final ok = await confirm(context,
                              title: 'Log out?',
                              message: 'You will need to verify your number again to sign in.',
                              confirmLabel: 'Log out',
                              destructive: true);
                          if (ok) await ref.read(authProvider.notifier).logout();
                        },
                      ),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  const Center(child: BrandLockup(markSize: 26, light: false)),
                  const SizedBox(height: 6),
                  Center(child: Text('Version 1.0.0', style: theme.textTheme.bodySmall)),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge(this.icon, {this.danger = false});
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFCE4E7) : AppColors.lavender,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: danger ? AppColors.danger : AppColors.indigo),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _IconBadge(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 1),
              Text(value, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            _IconBadge(icon, danger: danger),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: danger ? AppColors.danger : AppColors.ink)),
            ),
            if (!danger) const Icon(Icons.chevron_right_rounded, color: AppColors.offline),
          ]),
        ),
      );
}

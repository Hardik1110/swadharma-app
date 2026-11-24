import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../consultation/domain/consultation.dart';
import '../consultation/presentation/providers/consultation_controller.dart';

/// Bottom-navigation shell with a banner to rejoin an active consultation.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeConsultationProvider);
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.hairline)),
          boxShadow: [
            BoxShadow(
                color: AppColors.indigo.withValues(alpha: .06),
                blurRadius: 20,
                offset: const Offset(0, -4)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (active != null) _ActiveBanner(active),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (i) =>
                shell.goBranch(i, initialLocation: i == shell.currentIndex),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome_rounded),
                  label: 'Astrologers'),
              NavigationDestination(
                  icon: Icon(Icons.forum_outlined),
                  selectedIcon: Icon(Icons.forum_rounded),
                  label: 'Consultations'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile'),
            ],
          ),
        ]),
      ),
    );
  }
}

class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner(this.c);
  final Consultation c;

  @override
  Widget build(BuildContext context) {
    final waiting = c.status == ConsultationStatus.requested;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: AppColors.indigo.withValues(alpha: .28),
                blurRadius: 14,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const Key('active_banner'),
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.push(Routes.consultation(c.id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
              child: Row(children: [
                AppAvatar(
                    name: c.astrologerName,
                    url: c.astrologerAvatar,
                    size: 38,
                    ring: true,
                    statusColor: waiting ? AppColors.gold : AppColors.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      waiting ? 'Waiting for ${c.astrologerName}' : '${c.type.label} in progress',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    Text(
                      waiting ? 'Tap to view your request' : 'with ${c.astrologerName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 12.5),
                    ),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.saffron,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(waiting ? 'View' : 'Rejoin',
                      style: const TextStyle(
                          color: AppColors.onSaffron, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../consultation/domain/consultation.dart';
import '../providers/desk_providers.dart';

/// Bottom navigation for the astrologer app. Alerts (haptic + snackbar) when a
/// new request arrives, and shows how many are waiting.
class DeskShell extends ConsumerWidget {
  const DeskShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<List<Consultation>>(pendingRequestsProvider, (prev, next) {
      final known = {for (final c in prev ?? const <Consultation>[]) c.id};
      final fresh = next.where((c) => !known.contains(c.id)).toList();
      if (fresh.isEmpty || prev == null) return;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      final first = fresh.first;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('New ${first.type.label.toLowerCase()} request from ${first.userName}'),
          action: SnackBarAction(
            label: 'View',
            textColor: AppColors.gold,
            onPressed: () => shell.goBranch(0),
          ),
        ));
    });

    final pending = ref.watch(pendingRequestsProvider).length;
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
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            NavigationDestination(
              icon: Badge(
                isLabelVisible: pending > 0,
                label: Text('$pending'),
                backgroundColor: AppColors.saffron,
                textColor: AppColors.onSaffron,
                child: const Icon(Icons.inbox_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: pending > 0,
                label: Text('$pending'),
                backgroundColor: AppColors.saffron,
                textColor: AppColors.onSaffron,
                child: const Icon(Icons.inbox_rounded),
              ),
              label: 'Requests',
            ),
            const NavigationDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum_rounded),
                label: 'Consultations'),
            const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

/// Where the astrologer's tabs live in the route tree.
const deskRoutes = [Routes.desk, Routes.deskHistory, Routes.deskProfile];

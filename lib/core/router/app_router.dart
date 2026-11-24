import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/astrologers/presentation/pages/astrologer_detail_page.dart';
import '../../features/astrologers/presentation/pages/astrologer_list_page.dart';
import '../../features/auth/domain/user.dart';
import '../../features/desk/presentation/pages/desk_dashboard_page.dart';
import '../../features/desk/presentation/pages/desk_profile_page.dart';
import '../../features/desk/presentation/pages/desk_shell.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/consultation/presentation/pages/consultation_page.dart';
import '../../features/consultation/presentation/pages/history_page.dart';
import '../../features/home/home_shell.dart';
import '../../features/profile/presentation/pages/profile_form_page.dart';
import '../../features/wallet/presentation/pages/wallet_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Where an authenticated/unauthenticated user is allowed to be.
String? authRedirect(AsyncValue<User?> auth, String location) {
  const publicOnly = {Routes.splash, Routes.login};
  if (auth.isLoading && !auth.hasValue) {
    return location == Routes.splash ? null : Routes.splash;
  }
  final user = auth.value;
  if (user == null) return location == Routes.login ? null : Routes.login;

  // Astrologers have their own app: the desk, plus the shared consultation screen.
  if (user.isAstrologer) {
    final inDesk = location.startsWith(Routes.desk) || location.startsWith('/consultation/');
    return inDesk ? null : Routes.desk;
  }
  // Consumers never see the desk.
  if (location.startsWith(Routes.desk)) return Routes.astrologers;

  if (!user.profileComplete) {
    return location == Routes.profileSetup ? null : Routes.profileSetup;
  }
  if (publicOnly.contains(location) || location == Routes.profileSetup) {
    return Routes.astrologers;
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the session changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(authProvider), state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: Routes.profileSetup, builder: (_, _) => const ProfileFormPage()),
      GoRoute(
        path: Routes.editProfile,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ProfileFormPage(isEdit: true),
      ),
      GoRoute(
        path: Routes.wallet,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const WalletPage(),
      ),
      GoRoute(
        path: '/consultation/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ConsultationPage(sessionId: s.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => DeskShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.desk, builder: (_, _) => const DeskDashboardPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.deskHistory, builder: (_, _) => const HistoryPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.deskProfile, builder: (_, _) => const DeskProfilePage()),
          ]),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.astrologers,
              builder: (_, _) => const AstrologerListPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootKey,
                  builder: (_, s) => AstrologerDetailPage(id: s.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.history, builder: (_, _) => const HistoryPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.profile, builder: (_, _) => const ProfilePage()),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

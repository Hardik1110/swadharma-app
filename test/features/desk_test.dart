import 'package:astro_connect/core/errors/app_exception.dart';
import 'package:astro_connect/core/network/realtime_providers.dart';
import 'package:astro_connect/features/auth/data/auth_repository_impl.dart';
import 'package:astro_connect/features/auth/domain/user.dart';
import 'package:astro_connect/features/consultation/data/consultation_repository.dart';
import 'package:astro_connect/features/consultation/domain/chat_message.dart';
import 'package:astro_connect/features/consultation/domain/consultation.dart';
import 'package:astro_connect/features/consultation/presentation/providers/consultation_controller.dart';
import 'package:astro_connect/features/desk/data/desk_repository.dart';
import 'package:astro_connect/features/desk/presentation/pages/desk_dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../golden/harness.dart';
import '../helpers.dart';

const _astrologer = User(
  id: 'a1',
  phone: '9100000001',
  name: 'Pt. Raghav Sharma',
  role: 'astrologer',
  astrologerId: 'a1',
);

Consultation _request(String id, String name, {String type = 'chat'}) {
  final j = sessionJson(id: id, type: type, status: 'requested', userName: name);
  // The server sets requestedAt/serverTime; keep them close so timers read sensibly.
  j['requestedAt'] = DateTime.now().subtract(const Duration(seconds: 12)).toUtc().toIso8601String();
  return Consultation.fromJson(j);
}

void main() {
  late FakeConsultationRepository sessions;
  late FakeDeskRepository desk;

  List<Override> overrides() => [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()..user = _astrologer),
        consultationRepositoryProvider.overrideWithValue(sessions),
        deskRepositoryProvider.overrideWithValue(desk),
        socketClientProvider.overrideWithValue(FakeSocket()),
        viewerSenderProvider.overrideWithValue(MessageSender.astrologer),
      ];

  List<GoRoute> routes() => [
        GoRoute(path: '/', builder: (_, _) => const DeskDashboardPage()),
        GoRoute(
          path: '/consultation/:id',
          builder: (_, s) => Scaffold(body: Text('opened ${s.pathParameters['id']}')),
        ),
      ];

  setUp(() {
    sessions = FakeConsultationRepository();
    desk = FakeDeskRepository();
  });

  group('dashboard', () {
    testWidgets('shows availability, today\'s numbers and waiting requests', (tester) async {
      sessions.historyList = [_request('r1', 'Asha Verma'), _request('r2', 'Rohit Kumar', type: 'video')];
      final c = await pumpRouted(tester, routes(), overrides: overrides());

      expect(find.text('Pt. Raghav Sharma'), findsOneWidget);
      expect(find.text('You are online'), findsOneWidget);
      expect(find.text('₹420'), findsOneWidget, reason: 'earned today');
      expect(find.text('₹1,540'), findsOneWidget, reason: 'total earned');
      expect(find.text('2 waiting'), findsOneWidget);
      expect(find.byKey(const Key('request_r1')), findsOneWidget);
      expect(find.byKey(const Key('request_r2')), findsOneWidget);
      expect(find.text('Asha Verma'), findsOneWidget);
      expect(find.text('Rohit Kumar'), findsOneWidget);
      // The astrologer sees the customer's birth details on the card.
      expect(find.textContaining('Pune, Maharashtra'), findsWidgets);
      await disposeScreen(tester, c);
    });

    testWidgets('empty state explains what happens next', (tester) async {
      sessions.historyList = [];
      final c = await pumpRouted(tester, routes(), overrides: overrides());
      expect(find.text('No requests right now'), findsOneWidget);
      await disposeScreen(tester, c);
    });

    testWidgets('accepting opens the consultation', (tester) async {
      sessions.historyList = [_request('r1', 'Asha Verma')];
      final c = await pumpRouted(tester, routes(), overrides: overrides());

      await tester.tap(find.byKey(const Key('accept_r1')));
      await tester.pumpAndSettle();
      expect(find.text('opened r1'), findsOneWidget);
      await disposeScreen(tester, c);
    });

    testWidgets('declining removes the request from the list', (tester) async {
      sessions.historyList = [_request('r1', 'Asha Verma')];
      final c = await pumpRouted(tester, routes(), overrides: overrides());

      // After the server declines it, it is no longer pending.
      sessions.historyList = [
        Consultation.fromJson(sessionJson(id: 'r1', status: 'rejected', endReason: 'astrologer_declined')),
      ];
      await tester.tap(find.byKey(const Key('decline_r1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('request_r1')), findsNothing);
      expect(find.text('No requests right now'), findsOneWidget);
      await disposeScreen(tester, c);
    });

    testWidgets('availability switch goes offline and says so', (tester) async {
      final c = await pumpRouted(tester, routes(), overrides: overrides());
      await tester.tap(find.byKey(const Key('availability_switch')));
      await tester.pumpAndSettle();

      expect(desk.onlineCalls, [false]);
      expect(find.text('You are offline'), findsWidgets);
      expect(find.textContaining('Go online'), findsWidgets);
      await disposeScreen(tester, c);
    });

    testWidgets('going offline during a consultation shows the server\'s reason', (tester) async {
      desk.setOnlineError = const AppException(
          'Finish your current consultation before changing availability.',
          code: 'session_active',
          statusCode: 409);
      final c = await pumpRouted(tester, routes(), overrides: overrides());
      await tester.tap(find.byKey(const Key('availability_switch')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Finish your current consultation'), findsOneWidget);
      expect(find.text('You are online'), findsOneWidget, reason: 'unchanged');
      await disposeScreen(tester, c);
    });

    testWidgets('an ongoing consultation can be reopened', (tester) async {
      sessions.historyList = [
        Consultation.fromJson(sessionJson(id: 'live', type: 'chat', earning: 14)),
      ];
      final c = await pumpRouted(tester, routes(), overrides: overrides());
      expect(find.byKey(const Key('active_consultation')), findsOneWidget);
      await tester.tap(find.byKey(const Key('active_consultation')));
      await tester.pumpAndSettle();
      expect(find.text('opened live'), findsOneWidget);
      await disposeScreen(tester, c);
    });
  });
}

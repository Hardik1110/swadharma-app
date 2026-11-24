import 'package:astro_connect/core/network/realtime_providers.dart';
import 'package:astro_connect/features/astrologers/domain/astrologer.dart';
import 'package:astro_connect/features/astrologers/presentation/providers/astrologer_providers.dart';
import 'package:astro_connect/features/auth/data/auth_repository_impl.dart';
import 'package:astro_connect/features/auth/domain/user.dart';
import 'package:astro_connect/features/auth/presentation/pages/login_page.dart';
import 'package:astro_connect/features/consultation/data/consultation_repository.dart';
import 'package:astro_connect/features/consultation/domain/chat_message.dart';
import 'package:astro_connect/features/consultation/domain/consultation.dart';
import 'package:astro_connect/features/consultation/presentation/pages/consultation_page.dart';
import 'package:astro_connect/features/consultation/presentation/pages/history_page.dart';
import 'package:astro_connect/features/consultation/presentation/providers/consultation_controller.dart';
import 'package:astro_connect/features/desk/data/desk_repository.dart';
import 'package:astro_connect/features/desk/presentation/pages/desk_dashboard_page.dart';
import 'package:astro_connect/features/desk/presentation/pages/desk_profile_page.dart';
import 'package:flutter/material.dart' show Key, Size;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'harness.dart';

const _astrologer = User(
  id: 'a1',
  phone: '9100000001',
  name: 'Pt. Raghav Sharma',
  role: 'astrologer',
  astrologerId: 'a1',
);

Map<String, dynamic> _msg(String id, String sender, String text, String at) =>
    {'id': id, 'sessionId': 's1', 'sender': sender, 'text': text, 'sentAt': at};

Consultation _req(String id, String name, {String type = 'chat', int waited = 14}) {
  final j = sessionJson(id: id, type: type, status: 'requested', userName: name);
  j['requestedAt'] = DateTime.now().subtract(Duration(seconds: waited)).toUtc().toIso8601String();
  return Consultation.fromJson(j);
}

void main() {
  List<Override> base(FakeConsultationRepository repo, {FakeDeskRepository? desk}) => [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()..user = _astrologer),
        consultationRepositoryProvider.overrideWithValue(repo),
        deskRepositoryProvider.overrideWithValue(desk ?? FakeDeskRepository()),
        socketClientProvider.overrideWithValue(FakeSocket()),
        viewerSenderProvider.overrideWithValue(MessageSender.astrologer),
      ];

  testWidgets('desk_dashboard', (t) {
    final repo = FakeConsultationRepository()
      ..historyList = [
        _req('r1', 'Asha Verma'),
        _req('r2', 'Rohit Kumar', type: 'video', waited: 41),
        Consultation.fromJson(sessionJson(id: 'live', type: 'chat', earning: 14, userName: 'Meera Nair')),
      ];
    return snapshot(t, 'desk_dashboard', const DeskDashboardPage(),
        size: const Size(390, 1100), overrides: base(repo));
  });

  testWidgets('desk_dashboard_empty', (t) {
    final repo = FakeConsultationRepository()..historyList = [];
    return snapshot(t, 'desk_dashboard_empty', const DeskDashboardPage(),
        overrides: base(repo, desk: FakeDeskRepository(online: false)));
  });

  testWidgets('desk_request', (t) {
    final repo = FakeConsultationRepository()
      ..session = Consultation.fromJson(sessionJson(type: 'video', status: 'requested'));
    return snapshot(t, 'desk_request', const ConsultationPage(sessionId: 's1'), overrides: base(repo));
  });

  testWidgets('desk_chat', (t) {
    final repo = FakeConsultationRepository()
      ..session = Consultation.fromJson(sessionJson(chargedMinutes: 2, earning: 28))
      ..storedMessages = [
        ChatMessage.fromJson(_msg('1', 'system', 'Pt. Raghav Sharma joined the consultation', '2026-11-24T10:00:05Z')),
        ChatMessage.fromJson(_msg('2', 'astrologer', 'Namaste Asha. I can see you were born in Pune on 15 August 1995. What would you like to ask?', '2026-11-24T10:00:30Z')),
        ChatMessage.fromJson(_msg('3', 'user', 'Will I get a job change this year?', '2026-11-24T10:01:02Z')),
      ];
    return snapshot(t, 'desk_chat', const ConsultationPage(sessionId: 's1'), overrides: base(repo));
  });

  testWidgets('desk_summary', (t) {
    final repo = FakeConsultationRepository()
      ..session = Consultation.fromJson(
          sessionJson(status: 'completed', endReason: 'user_ended', earning: 17, chargedMinutes: 5));
    return snapshot(t, 'desk_summary', const ConsultationPage(sessionId: 's1'),
        size: const Size(390, 900), overrides: base(repo));
  });

  testWidgets('desk_profile', (t) {
    final repo = FakeConsultationRepository()..historyList = [];
    return snapshot(t, 'desk_profile', const DeskProfilePage(),
        size: const Size(390, 1000), overrides: base(repo));
  });

  testWidgets('desk_history', (t) {
    final done = sessionJson(id: 'h1', status: 'completed', endReason: 'user_ended', earning: 17, userName: 'Asha Verma');
    final repo = FakeConsultationRepository()
      ..historyList = [
        Consultation.fromJson(done),
        Consultation.fromJson(sessionJson(id: 'h2', type: 'voice', status: 'completed', endReason: 'user_ended', earning: 35, userName: 'Rohit Kumar')),
        Consultation.fromJson(sessionJson(id: 'h3', status: 'rejected', endReason: 'astrologer_declined', userName: 'Meera Nair')),
      ];
    return snapshot(t, 'desk_history', const HistoryPage(), overrides: base(repo));
  });

  testWidgets('login_astrologer', (t) => snapshot(
        t,
        'login_astrologer',
        const LoginPage(),
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          appConfigProvider.overrideWith((ref) async => const AppConfig(callsEnabled: true, expertise: [])),
        ],
        interact: (t) async {
          await t.tap(find.byKey(const Key('astrologer_login')));
          await t.pump(const Duration(milliseconds: 500));
        },
      ));
}

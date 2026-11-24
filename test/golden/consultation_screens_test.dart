import 'package:astro_connect/core/network/realtime_providers.dart';
import 'package:flutter/material.dart' show Size;
import 'package:astro_connect/features/consultation/data/consultation_repository.dart';
import 'package:astro_connect/features/consultation/domain/chat_message.dart';
import 'package:astro_connect/features/consultation/domain/consultation.dart';
import 'package:astro_connect/features/consultation/presentation/pages/consultation_page.dart';
import 'package:astro_connect/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'harness.dart';

Map<String, dynamic> _msg(String id, String sender, String text, String at) => {
      'id': id,
      'sessionId': 's1',
      'sender': sender,
      'text': text,
      'sentAt': at,
    };

void main() {
  List<dynamic> overrides(FakeConsultationRepository repo, {int balance = 250}) => [
        consultationRepositoryProvider.overrideWithValue(repo),
        socketClientProvider.overrideWithValue(FakeSocket()),
        walletProvider.overrideWith(() => FakeWalletNotifier(balance: balance)),
      ];

  testWidgets('waiting', (t) {
    final repo = FakeConsultationRepository()
      ..session = Consultation.fromJson(sessionJson(status: 'requested'));
    return snapshot(t, 'waiting', const ConsultationPage(sessionId: 's1'),
        overrides: overrides(repo).cast());
  });

  testWidgets('chat', (t) {
    final repo = FakeConsultationRepository()
      ..storedMessages = [
        ChatMessage.fromJson(_msg('1', 'system', 'Pt. Raghav Sharma joined the consultation', '2026-11-24T10:00:05Z')),
        ChatMessage.fromJson(_msg('2', 'astrologer', 'Namaste Hardik 🙏 I am Pt. Raghav Sharma. I see you are a Leo. What would you like to ask today?', '2026-11-24T10:00:08Z')),
        ChatMessage.fromJson(_msg('3', 'user', 'Will I get a job change this year?', '2026-11-24T10:01:02Z')),
        ChatMessage.fromJson(_msg('4', 'astrologer', 'For Leo, Saturn is strengthening your 10th house. The next 3–4 months favour a change.', '2026-11-24T10:01:20Z')),
        ChatMessage.fromJson(_msg('5', 'user', 'That is great, thank you!', '2026-11-24T10:02:00Z')),
      ];
    return snapshot(t, 'chat', const ConsultationPage(sessionId: 's1'),
        overrides: overrides(repo).cast());
  });

  testWidgets('chat_low_balance', (t) {
    final repo = FakeConsultationRepository()
      ..session = Consultation.fromJson(
          sessionJson(chargedMinutes: 3, paidFor: const Duration(seconds: 42)))
      ..storedMessages = [
        ChatMessage.fromJson(_msg('1', 'system', 'Pt. Raghav Sharma joined the consultation', '2026-11-24T10:00:05Z')),
        ChatMessage.fromJson(_msg('2', 'astrologer', 'The next three months favour a change of role.', '2026-11-24T10:02:20Z')),
        ChatMessage.fromJson(_msg('3', 'user', 'Should I accept an offer from another city?', '2026-11-24T10:02:50Z')),
      ];
    // Balance 10 < 25/min: the next minute can't be paid.
    return snapshot(t, 'chat_low_balance', const ConsultationPage(sessionId: 's1'),
        overrides: overrides(repo, balance: 10).cast());
  });

  testWidgets('summary', (t) {
    final repo = FakeConsultationRepository()
      ..session = Consultation.fromJson(sessionJson(status: 'completed', endReason: 'user_ended'));
    return snapshot(t, 'summary', const ConsultationPage(sessionId: 's1'),
        overrides: overrides(repo).cast(),
        size: const Size(390, 900));
  });
}

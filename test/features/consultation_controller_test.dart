import 'package:astro_connect/core/network/realtime_providers.dart';
import 'package:astro_connect/features/consultation/data/consultation_repository.dart';
import 'package:astro_connect/features/consultation/domain/chat_message.dart';
import 'package:astro_connect/features/consultation/domain/consultation.dart';
import 'package:astro_connect/features/consultation/presentation/providers/consultation_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late FakeConsultationRepository repo;
  late FakeSocket socket;
  late ProviderContainer container;
  final provider = consultationControllerProvider('s1');

  setUp(() async {
    repo = FakeConsultationRepository()
      ..storedMessages = [ChatMessage.fromJson(messageJson('m0', 'system', 'Joined'))];
    socket = FakeSocket();
    container = ProviderContainer.test(overrides: [
      consultationRepositoryProvider.overrideWithValue(repo),
      socketClientProvider.overrideWithValue(socket),
    ]);
    container.listen(provider, (_, _) {});
    await container.read(provider.future);
  });

  ConsultationState state() => container.read(provider).requireValue;
  ConsultationController ctrl() => container.read(provider.notifier);

  test('loads session and history', () {
    expect(state().session.status, ConsultationStatus.ongoing);
    expect(state().messages.single.text, 'Joined');
  });

  test('optimistic send over socket is confirmed by the server echo', () async {
    ctrl().sendMessage('  How is my career?  ');
    final pending = state().messages.last;
    expect(pending.delivery, DeliveryState.sending);
    expect(pending.text, 'How is my career?');
    expect(socket.sent.single.$1, 'chat.send');

    socket.emit('chat.message',
        messageJson('m1', 'user', 'How is my career?', clientId: pending.clientId));
    await pumpEventQueue();
    expect(state().messages.length, 2);
    expect(state().messages.last.id, 'm1');
    expect(state().messages.last.delivery, DeliveryState.sent);
  });

  test('falls back to REST when the socket is down', () async {
    socket.connected = false;
    ctrl().sendMessage('hello');
    await pumpEventQueue();
    expect(repo.restSent, ['hello']);
    expect(state().messages.last.delivery, DeliveryState.sent);
  });

  test('failed send can be retried', () async {
    socket.connected = false;
    repo.failSend = true;
    ctrl().sendMessage('hello');
    await pumpEventQueue();
    final failed = state().messages.last;
    expect(failed.delivery, DeliveryState.failed);

    repo.failSend = false;
    ctrl().retry(failed);
    await pumpEventQueue();
    expect(state().messages.where((m) => m.text == 'hello').single.delivery,
        DeliveryState.sent);
  });

  test('astrologer typing and replies', () async {
    socket.emit('typing', {'sessionId': 's1', 'sender': 'astrologer'});
    await pumpEventQueue();
    expect(state().peerTyping, isTrue);

    socket.emit('chat.message', messageJson('m2', 'astrologer', 'Jupiter is strong'));
    await pumpEventQueue();
    expect(state().peerTyping, isFalse);
    expect(state().messages.last.text, 'Jupiter is strong');
  });

  test('ignores events for other sessions and duplicate messages', () async {
    socket.emit('chat.message', {...messageJson('x', 'astrologer', 'other'), 'sessionId': 's2'});
    socket.emit('chat.message', messageJson('m0', 'system', 'Joined'));
    await pumpEventQueue();
    expect(state().messages.length, 1);
  });

  test('session.updated from the server ends the consultation', () async {
    socket.emit('session.updated', sessionJson(status: 'completed', endReason: 'astrologer_ended'));
    await pumpEventQueue();
    expect(state().session.status, ConsultationStatus.completed);
    expect(state().session.endReasonText, contains('ended the consultation'));
  });

  test('ending updates state from the API response', () async {
    await ctrl().end();
    expect(state().session.status, ConsultationStatus.completed);
    expect(state().session.endReason, 'user_ended');
  });
}

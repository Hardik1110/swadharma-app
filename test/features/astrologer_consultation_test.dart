import 'package:astro_connect/core/network/realtime_providers.dart';
import 'package:astro_connect/features/consultation/data/consultation_repository.dart';
import 'package:astro_connect/features/consultation/domain/chat_message.dart';
import 'package:astro_connect/features/consultation/domain/consultation.dart';
import 'package:astro_connect/features/consultation/presentation/pages/consultation_page.dart';
import 'package:astro_connect/features/consultation/presentation/providers/consultation_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../golden/harness.dart';
import '../helpers.dart';

Map<String, dynamic> _msg(String id, String sender, String text, {String at = '2026-11-24T10:01:00Z'}) => {
      'id': id,
      'sessionId': 's1',
      'sender': sender,
      'text': text,
      'sentAt': at,
    };

void main() {
  late FakeConsultationRepository repo;
  late FakeSocket socket;

  List<Override> overrides({MessageSender viewer = MessageSender.astrologer}) => [
        consultationRepositoryProvider.overrideWithValue(repo),
        socketClientProvider.overrideWithValue(socket),
        viewerSenderProvider.overrideWithValue(viewer),
      ];

  List<GoRoute> routes() => [
        GoRoute(path: '/', builder: (_, _) => const ConsultationPage(sessionId: 's1')),
      ];

  setUp(() {
    repo = FakeConsultationRepository();
    socket = FakeSocket();
  });

  group('astrologer view of a consultation', () {
    testWidgets('incoming request shows the customer and their birth details', (tester) async {
      repo.session = Consultation.fromJson(sessionJson(status: 'requested'));
      final c = await pumpRouted(tester, routes(), overrides: overrides());

      expect(find.text('New request'), findsOneWidget);
      expect(find.text('Asha Verma'), findsWidgets);
      expect(find.text('15 Aug 1995'), findsOneWidget);
      expect(find.text('Pune, Maharashtra'), findsOneWidget);
      expect(find.textContaining('Sun sign: Leo'), findsOneWidget);
      expect(find.byKey(const Key('accept_request')), findsOneWidget);
      expect(find.byKey(const Key('decline_request')), findsOneWidget);
      // None of the customer's "waiting" UI.
      expect(find.byKey(const Key('cancel_request')), findsNothing);
      await disposeScreen(tester, c);
    });

    testWidgets('accepting moves straight into the chat with an earnings strip', (tester) async {
      repo.session = Consultation.fromJson(sessionJson(status: 'requested'));
      final c = await pumpRouted(tester, routes(), overrides: overrides());

      await tester.tap(find.byKey(const Key('accept_request')));
      await tester.pump(const Duration(milliseconds: 600)); // an ongoing chat never "settles"

      expect(find.byKey(const Key('chat_input')), findsOneWidget);
      expect(find.byKey(const Key('earning_strip')), findsOneWidget);
      expect(find.byKey(const Key('session_meter')), findsNothing, reason: 'no wallet for astrologers');
      expect(find.byKey(const Key('birth_details_button')), findsOneWidget);
      await disposeScreen(tester, c);
    });

    testWidgets('declining ends in a "declined" summary worded for the astrologer', (tester) async {
      repo.session = Consultation.fromJson(sessionJson(status: 'requested'));
      final c = await pumpRouted(tester, routes(), overrides: overrides());

      await tester.tap(find.byKey(const Key('decline_request')));
      await tester.pumpAndSettle();

      expect(find.text('Request declined'), findsOneWidget);
      expect(find.text('You declined this request'), findsOneWidget);
      await disposeScreen(tester, c);
    });

    testWidgets('birth details stay one tap away during the chat', (tester) async {
      repo.session = Consultation.fromJson(sessionJson());
      final c = await pumpRouted(tester, routes(), overrides: overrides());

      await tester.tap(find.byKey(const Key('birth_details_button')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Birth details'), findsOneWidget);
      expect(find.text('Pune, Maharashtra'), findsOneWidget);
      await disposeScreen(tester, c);
    });

    testWidgets('my messages are on the right, the customer\'s on the left', (tester) async {
      repo.session = Consultation.fromJson(sessionJson());
      repo.storedMessages = [
        ChatMessage.fromJson(_msg('1', 'user', 'Will I change jobs this year?')),
        ChatMessage.fromJson(_msg('2', 'astrologer', 'Yes, within three months.')),
      ];
      final c = await pumpRouted(tester, routes(), overrides: overrides());

      final customer = tester.getTopLeft(find.text('Will I change jobs this year?')).dx;
      final mine = tester.getTopLeft(find.text('Yes, within three months.')).dx;
      expect(mine, greaterThan(customer), reason: 'astrologer\'s own bubble is right-aligned');
      await disposeScreen(tester, c);
    });

    testWidgets('the customer sees the same messages the other way round', (tester) async {
      repo.session = Consultation.fromJson(sessionJson());
      repo.storedMessages = [
        ChatMessage.fromJson(_msg('1', 'user', 'Will I change jobs this year?')),
        ChatMessage.fromJson(_msg('2', 'astrologer', 'Yes, within three months.')),
      ];
      final c = await pumpRouted(tester, routes(),
          overrides: [...overrides(viewer: MessageSender.user)]);

      final mine = tester.getTopLeft(find.text('Will I change jobs this year?')).dx;
      final astrologer = tester.getTopLeft(find.text('Yes, within three months.')).dx;
      expect(mine, greaterThan(astrologer));
      await disposeScreen(tester, c);
    });

    testWidgets('shows the customer typing', (tester) async {
      repo.session = Consultation.fromJson(sessionJson());
      final c = await pumpRouted(tester, routes(), overrides: overrides());
      expect(find.text('Customer'), findsOneWidget);

      socket.emit('typing', {'sessionId': 's1', 'sender': 'user'});
      await tester.pump();
      expect(find.text('typing…'), findsWidgets);
      await tester.pump(const Duration(seconds: 5)); // typing indicator times out
      await disposeScreen(tester, c);
    });

    testWidgets('finished consultation shows what the astrologer earned', (tester) async {
      repo.session = Consultation.fromJson(
          sessionJson(status: 'completed', endReason: 'user_ended', earning: 14));
      final c = await pumpRouted(tester, routes(), overrides: overrides());

      expect(find.text('Consultation complete'), findsOneWidget);
      expect(find.text('Asha Verma ended the consultation'), findsOneWidget);
      expect(find.byKey(const Key('earned_amount')), findsOneWidget);
      expect(find.text('₹14'), findsOneWidget);
      expect(find.text('Charged to customer'), findsOneWidget);
      // No rating form: astrologers don't rate customers.
      expect(find.byKey(const Key('star_1')), findsNothing);
      await disposeScreen(tester, c);
    });
  });

  group('controller from the astrologer\'s side', () {
    test('messages are sent as the astrologer; the customer typing is "peer typing"', () async {
      repo.session = Consultation.fromJson(sessionJson());
      final container = ProviderContainer.test(overrides: overrides());
      final provider = consultationControllerProvider('s1');
      container.listen(provider, (_, _) {});
      await container.read(provider.future);

      container.read(provider.notifier).sendMessage('Namaste');
      var state = container.read(provider).requireValue;
      expect(state.messages.last.sender, MessageSender.astrologer);
      expect(socket.sent.last.$1, 'chat.send');

      socket.emit('typing', {'sessionId': 's1', 'sender': 'user'});
      await pumpEventQueue();
      state = container.read(provider).requireValue;
      expect(state.peerTyping, isTrue);

      // The astrologer's own typing echo must not light the indicator.
      socket.emit('typing', {'sessionId': 's1', 'sender': 'astrologer'});
      socket.emit('chat.message', _msg('9', 'user', 'Hello'));
      await pumpEventQueue();
      expect(container.read(provider).requireValue.peerTyping, isFalse);
    });
  });
}

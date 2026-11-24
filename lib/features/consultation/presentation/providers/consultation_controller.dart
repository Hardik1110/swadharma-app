import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/realtime_providers.dart';
import '../../../../core/network/socket_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/consultation_repository.dart';
import '../../domain/chat_message.dart';
import '../../domain/consultation.dart';

class ConsultationState extends Equatable {
  const ConsultationState({
    required this.session,
    this.messages = const [],
    this.peerTyping = false,
  });

  final Consultation session;
  final List<ChatMessage> messages;
  final bool peerTyping;

  ConsultationState copyWith({
    Consultation? session,
    List<ChatMessage>? messages,
    bool? peerTyping,
  }) =>
      ConsultationState(
        session: session ?? this.session,
        messages: messages ?? this.messages,
        peerTyping: peerTyping ?? this.peerTyping,
      );

  @override
  List<Object?> get props => [session, messages, peerTyping];
}

/// Who "I" am in a conversation: the consumer or the astrologer.
final viewerSenderProvider = Provider<MessageSender>((ref) {
  final astrologer = ref.watch(authProvider.select((u) => u.value?.isAstrologer ?? false));
  return astrologer ? MessageSender.astrologer : MessageSender.user;
});

final consultationControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ConsultationController, ConsultationState, String>(
        ConsultationController.new);

/// Live state of one consultation: REST snapshot + WebSocket updates.
class ConsultationController extends AsyncNotifier<ConsultationState> {
  ConsultationController(this.sessionId);

  final String sessionId;

  static const sendTimeout = Duration(seconds: 10);

  Timer? _typingReset;
  DateTime _lastTypingSent = DateTime(0);
  final _pendingTimers = <String, Timer>{};
  final _rand = Random();

  ConsultationRepository get _repo => ref.read(consultationRepositoryProvider);

  MessageSender get _me => ref.read(viewerSenderProvider);

  /// The other side of the conversation.
  MessageSender get _peer =>
      _me == MessageSender.user ? MessageSender.astrologer : MessageSender.user;
  SocketClient get _socket => ref.read(socketClientProvider);

  @override
  Future<ConsultationState> build() async {
    final socket = ref.watch(socketClientProvider);
    final sub = socket.events.listen(_onEvent);
    ref.listen(socketStatusProvider, (prev, next) {
      // Anything could have happened while offline: resync.
      if (next == SocketStatus.connected && prev != SocketStatus.connected) {
        _resync();
      }
    });
    ref.onDispose(() {
      sub.cancel();
      _typingReset?.cancel();
      for (final t in _pendingTimers.values) {
        t.cancel();
      }
    });

    final (session, messages) =
        await (_repo.get(sessionId), _repo.messages(sessionId)).wait;
    return ConsultationState(session: session, messages: messages);
  }

  // ------------------------------------------------------------ actions

  void sendMessage(String text) {
    final current = state.value;
    final trimmed = text.trim();
    if (current == null || trimmed.isEmpty) return;
    final clientId = 'c${DateTime.now().microsecondsSinceEpoch}${_rand.nextInt(999)}';
    final pending = ChatMessage(
      id: clientId,
      sessionId: sessionId,
      sender: _me,
      text: trimmed,
      sentAt: current.session.serverNow,
      clientId: clientId,
      delivery: DeliveryState.sending,
    );
    _set(current.copyWith(messages: [...current.messages, pending]));
    _deliver(pending);
  }

  void retry(ChatMessage failed) {
    final current = state.value;
    if (current == null) return;
    _set(current.copyWith(
        messages: current.messages.where((m) => m.id != failed.id).toList()));
    sendMessage(failed.text);
  }

  void userTyping() {
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) < const Duration(seconds: 2)) return;
    _lastTypingSent = now;
    _socket.send('typing', {'sessionId': sessionId});
  }

  Future<void> cancelRequest() => _act(() => _repo.cancel(sessionId));

  /// Astrologer: take or decline the request.
  Future<void> accept() => _act(() => _repo.accept(sessionId));

  Future<void> reject() => _act(() => _repo.reject(sessionId));

  Future<void> end({String reason = 'user_ended'}) =>
      _act(() => _repo.end(sessionId, reason: reason));

  Future<void> rate(int rating, String comment) =>
      _act(() => _repo.review(sessionId, rating, comment));

  Future<void> refresh() => _resync();

  // ----------------------------------------------------------- internals

  Future<void> _act(Future<Consultation> Function() call) async {
    final session = await call(); // AppException propagates to the UI
    final current = state.value;
    if (current != null && ref.mounted) _set(current.copyWith(session: session));
  }

  Future<void> _deliver(ChatMessage m) async {
    if (_socket.send('chat.send',
        {'sessionId': sessionId, 'text': m.text, 'clientId': m.clientId})) {
      // Wait for the server echo; give up after a while.
      _pendingTimers[m.clientId!] = Timer(sendTimeout, () => _markFailed(m.clientId!));
      return;
    }
    try {
      _upsert(await _repo.sendMessage(sessionId, m.text, m.clientId!));
    } on AppException {
      _markFailed(m.clientId!);
    }
  }

  void _markFailed(String clientId) {
    _pendingTimers.remove(clientId)?.cancel();
    final current = state.value;
    if (current == null || !ref.mounted) return;
    _set(current.copyWith(
      messages: [
        for (final m in current.messages)
          m.clientId == clientId && m.delivery == DeliveryState.sending
              ? m.withDelivery(DeliveryState.failed)
              : m,
      ],
    ));
  }

  void _onEvent(SocketEvent e) {
    final current = state.value;
    if (current == null) return;
    final data = e.data;
    switch (e.type) {
      case 'session.updated' when data['id'] == sessionId:
        final session = Consultation.fromJson(data);
        _set(current.copyWith(
          session: session,
          peerTyping: session.status == ConsultationStatus.ongoing &&
              current.peerTyping,
        ));
      case 'chat.message' when data['sessionId'] == sessionId:
        final m = ChatMessage.fromJson(data);
        if (m.sender == _peer) {
          _typingReset?.cancel();
          _set(current.copyWith(peerTyping: false));
        }
        _upsert(m);
      case 'typing' when data['sessionId'] == sessionId && data['sender'] == _peer.name:
        _set(current.copyWith(peerTyping: true));
        _typingReset?.cancel();
        _typingReset = Timer(const Duration(seconds: 4), () {
          final s = state.value;
          if (s != null && ref.mounted) _set(s.copyWith(peerTyping: false));
        });
      case 'error' when data['sessionId'] == sessionId && data['clientId'] != null:
        _markFailed(data['clientId'] as String);
      default:
        break;
    }
  }

  /// Inserts a server message, replacing its optimistic copy if present.
  void _upsert(ChatMessage m) {
    final current = state.value;
    if (current == null || !ref.mounted) return;
    if (m.clientId != null) _pendingTimers.remove(m.clientId)?.cancel();
    final list = [...current.messages];
    final byClient =
        m.clientId == null ? -1 : list.indexWhere((x) => x.clientId == m.clientId);
    if (byClient >= 0) {
      list[byClient] = m;
    } else if (!list.any((x) => x.id == m.id)) {
      list.add(m);
    }
    _set(current.copyWith(messages: list));
  }

  Future<void> _resync() async {
    final current = state.value;
    if (current == null) return;
    try {
      final (session, messages) =
          await (_repo.get(sessionId), _repo.messages(sessionId)).wait;
      if (!ref.mounted) return;
      // Keep optimistic messages the server hasn't confirmed yet.
      final confirmed = messages.map((m) => m.clientId).whereType<String>().toSet();
      final pending = (state.value ?? current)
          .messages
          .where((m) => m.delivery != DeliveryState.sent && !confirmed.contains(m.clientId));
      _set(current.copyWith(session: session, messages: [...messages, ...pending]));
    } on ParallelWaitError<dynamic, dynamic> {
      // Keep showing what we have; the next reconnect retries.
    } on AppException {
      // Same as above.
    }
  }

  void _set(ConsultationState s) {
    if (ref.mounted) state = AsyncData(s);
  }
}

/// All of the user's consultations, newest first; refreshed on socket updates.
final consultationHistoryProvider =
    FutureProvider.autoDispose<List<Consultation>>((ref) {
  final sub = ref.watch(socketClientProvider).events.listen((e) {
    if (e.type == 'session.updated') ref.invalidateSelf();
  });
  ref.onDispose(sub.cancel);
  ref.listen(socketStatusProvider, (prev, next) {
    if (next == SocketStatus.connected && prev != SocketStatus.connected) {
      ref.invalidateSelf();
    }
  });
  return ref.watch(consultationRepositoryProvider).history();
});

/// The consultation currently waiting or in progress, if any.
final activeConsultationProvider = Provider.autoDispose<Consultation?>((ref) {
  final list = ref.watch(consultationHistoryProvider).value ?? const [];
  return list.where((c) => c.status.isActive).firstOrNull;
});

import 'dart:async';
import 'dart:math';

import 'bot.dart';
import 'hub.dart';
import 'models.dart';
import 'agora_token_info.dart';
import 'rtc_tokens.dart';
import 'store.dart';
import 'wallet_service.dart';

class ConsultationConfig {
  const ConsultationConfig({
    this.agoraAppId = '',
    this.agoraAppCertificate = '',
    this.agoraStaticToken = '',
    this.botAcceptDelay = const Duration(seconds: 4),
    this.requestTimeout = const Duration(seconds: 60),
    this.disconnectGrace = const Duration(seconds: 30),
    this.botTypingDelay = const Duration(milliseconds: 1800),
    this.simulatePresence = true,
    this.minuteDuration = const Duration(seconds: 60),
    this.billingTick = const Duration(seconds: 1),
    this.astrologerShare = 0.7,
  });

  /// Length of one billable minute (tests shorten it).
  final Duration minuteDuration;

  /// How often ongoing sessions are checked for the next minute's charge.
  final Duration billingTick;

  /// Fraction of each charge the astrologer earns.
  final double astrologerShare;

  /// Agora project App ID. Empty disables calls.
  final String agoraAppId;

  /// Agora App Certificate. When set, calls use signed tokens (required if the
  /// project has the certificate enabled); when empty the project must be in
  /// "testing mode" (App ID only).
  final String agoraAppCertificate;
  final Duration botAcceptDelay;
  final Duration requestTimeout;
  final Duration disconnectGrace;
  final Duration botTypingDelay;
  final bool simulatePresence;

  bool get callsEnabled => agoraAppId.isNotEmpty;

  /// A fixed Agora token (e.g. the console's 24-hour "temp token"). Every
  /// call then uses the one channel the token was made for, so only one call
  /// can run at a time. A stop-gap for demos when the project has a
  /// certificate but no token server is set up.
  final String agoraStaticToken;

  AgoraTokenInfo? get staticTokenInfo =>
      agoraStaticToken.isEmpty ? null : AgoraTokenInfo.parse(agoraStaticToken);

  bool get usesStaticToken => agoraStaticToken.isNotEmpty;

  bool get usesTokens => agoraAppId.isNotEmpty && agoraAppCertificate.isNotEmpty;
}

/// Owns the consultation lifecycle:
/// requested -> ongoing -> completed, or requested -> rejected/cancelled/missed.
class ConsultationService {
  ConsultationService(this.store, this.hub, this.config,
      {AstroBot? bot, WalletService? wallet})
      : _bot = bot ?? AstroBot(),
        wallet = wallet ?? WalletService(store, hub) {
    _billingTimer = Timer.periodic(config.billingTick, (_) => _billOngoing());
    if (config.simulatePresence) {
      _presenceTimer =
          Timer.periodic(const Duration(seconds: 90), (_) => _togglePresence());
    }
  }

  final Store store;
  final Hub hub;
  final ConsultationConfig config;
  final WalletService wallet;
  final AstroBot _bot;
  late final RtcTokenService? _tokens = config.usesTokens
      ? RtcTokenService(appId: config.agoraAppId, appCertificate: config.agoraAppCertificate)
      : null;
  Timer? _billingTimer;
  final _timers = <String, List<Timer>>{};
  final _disconnectTimers = <String, Timer>{};
  Timer? _presenceTimer;
  final _rand = Random();

  void dispose() {
    _billingTimer?.cancel();
    _presenceTimer?.cancel();
    for (final list in _timers.values) {
      for (final t in list) {
        t.cancel();
      }
    }
    for (final t in _disconnectTimers.values) {
      t.cancel();
    }
  }

  // ---------------------------------------------------------------- queries

  Map<String, dynamic> sessionJson(Session s) {
    final a = store.astrologers[s.astrologerId]!;
    final u = store.users[s.userId];
    final last = store.messages[s.id]?.lastOrNull;
    return {
      ...s.toJson(),
      'durationSeconds': s.durationSeconds,
      'cost': s.cost,
      'astrologer': {'id': a.id, 'name': a.name, 'avatarUrl': a.avatarUrl},
      'user': u == null
          ? null
          : {
              'name': u.name,
              'dob': u.dob,
              'birthTime': u.birthTime,
              'birthPlace': u.birthPlace,
            },
      'paidUntil': s.startedAt
          ?.add(config.minuteDuration * s.chargedMinutes)
          .toUtc()
          .toIso8601String(),
      'earning': (s.cost * config.astrologerShare).floor(),
      'rtc': s.isCall && config.callsEnabled
          ? {
              'appId': config.agoraAppId,
              'channel': _channelFor(s),
              'token': config.usesStaticToken
                  ? config.agoraStaticToken
                  : _tokens?.tokenFor(s.channelName),
            }
          : null,
      'lastMessage': last?.toJson(),
      'serverTime': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// The Agora channel for [s]: its own, or the fixed one a static token allows.
  String _channelFor(Session s) =>
      config.staticTokenInfo?.channel ?? s.channelName;

  Session requireOwned(User u, String id) {
    final s = store.sessions[id];
    if (s == null || s.userId != u.id) {
      throw ApiError(404, 'not_found', 'Consultation not found');
    }
    return s;
  }

  Session requireSession(String id) {
    final s = store.sessions[id];
    if (s == null) throw ApiError(404, 'not_found', 'Consultation not found');
    return s;
  }

  // -------------------------------------------------------------- lifecycle

  Session create(User user, String astrologerId, SessionType type) {
    if (!user.profileComplete) {
      throw ApiError(400, 'profile_incomplete',
          'Complete your birth details before starting a consultation');
    }
    final a = store.astrologers[astrologerId];
    if (a == null) throw ApiError(404, 'not_found', 'Astrologer not found');
    if (type != SessionType.chat && !config.callsEnabled) {
      throw ApiError(503, 'calls_unavailable',
          'Voice and video calls are not configured on the server');
    }
    // Voice and video need a person on the other end of the Agora channel;
    // the chat bot can't speak or show video. Fail fast instead of leaving
    // the user alone in an empty call.
    if (type != SessionType.chat && !hub.hasConsole(a.id)) {
      throw ApiError(
          409,
          'astrologer_not_live',
          '${a.name} takes voice and video calls live and isn\'t available for '
              'them right now. You can start a chat instead.');
    }
    if (type != SessionType.chat && config.usesStaticToken) {
      final info = config.staticTokenInfo;
      if (info == null || info.isExpired()) {
        throw ApiError(503, 'call_token_expired',
            'Calls are temporarily unavailable: the demo call token has expired. You can chat instead.');
      }
      // One channel, one call at a time.
      final lineBusy = store.sessions.values.any((o) => o.isCall && o.isActive);
      if (lineBusy) {
        throw ApiError(409, 'call_line_busy',
            'Another call is in progress on the demo line. Please try again in a moment, or chat instead.');
      }
    }
    final existing = store.activeSessionFor(user.id);
    if (existing != null) {
      throw ApiError(409, 'session_active',
          'You already have an active consultation. Finish it first.');
    }
    final rate = a.pricing[type.name]!;
    if (user.balance < rate) {
      throw ApiError(
          402,
          'insufficient_balance',
          'Your wallet balance is ₹${user.balance}. A ${type.name} with '
              '${a.name} costs ₹$rate per minute, so please add money to start.');
    }
    switch (a.status) {
      case AstrologerStatus.offline:
        throw ApiError(409, 'astrologer_offline', '${a.name} is offline right now');
      case AstrologerStatus.busy:
        throw ApiError(409, 'astrologer_busy',
            '${a.name} is in another consultation. Please try again shortly.');
      case AstrologerStatus.online:
        break;
    }

    final s = Session(
      id: newId(6),
      userId: user.id,
      astrologerId: a.id,
      type: type,
      ratePerMinute: rate,
    );
    store.sessions[s.id] = s;
    store.scheduleSave();
    _notify(s);

    _after(s.id, config.requestTimeout, () {
      if (s.status == SessionStatus.requested) {
        _finish(s, SessionStatus.missed, 'timeout');
      }
    });
    if (!hub.hasConsole(a.id)) {
      _after(s.id, config.botAcceptDelay, () {
        if (s.status == SessionStatus.requested) accept(s.id);
      });
    }
    return s;
  }

  void accept(String id) {
    final s = requireSession(id);
    if (s.status != SessionStatus.requested) {
      throw ApiError(409, 'invalid_state', 'Request is no longer pending');
    }
    final a = store.astrologers[s.astrologerId]!;
    if (a.status == AstrologerStatus.busy) {
      _finish(s, SessionStatus.rejected, 'astrologer_busy');
      return;
    }
    // The first minute is paid up front; the balance may have changed since
    // the request was made.
    final payer = store.users[s.userId]!;
    if (!wallet.charge(payer, s.ratePerMinute,
        note: 'Consultation with ${a.name}: minute 1', session: s)) {
      _finish(s, SessionStatus.rejected, 'insufficient_balance');
      return;
    }
    s.chargedMinutes = 1;
    _cancelTimers(s.id);
    s.status = SessionStatus.ongoing;
    s.startedAt = DateTime.now();
    _setStatus(a, AstrologerStatus.busy);
    // Other users waiting on this astrologer can't be served now.
    for (final other in store.sessions.values.where((o) =>
        o.id != s.id &&
        o.astrologerId == a.id &&
        o.status == SessionStatus.requested)) {
      _finish(other, SessionStatus.rejected, 'astrologer_busy');
    }
    _system(s, '${a.name} joined the consultation');
    store.scheduleSave();
    _notify(s);

    if (!hub.hasConsole(a.id) && s.type == SessionType.chat) {
      final user = store.users[s.userId]!;
      _botSay(s, _bot.greeting(a, user));
    }
  }

  void reject(String id, [String reason = 'astrologer_declined']) {
    final s = requireSession(id);
    if (s.status != SessionStatus.requested) {
      throw ApiError(409, 'invalid_state', 'Request is no longer pending');
    }
    _finish(s, SessionStatus.rejected, reason);
  }

  void cancel(User user, String id) {
    final s = requireOwned(user, id);
    if (s.status != SessionStatus.requested) {
      throw ApiError(409, 'invalid_state', 'Only pending requests can be cancelled');
    }
    _finish(s, SessionStatus.cancelled, 'user_cancelled');
  }

  /// Ends an ongoing session (or cancels a pending one).
  void end(String id, String reason) {
    final s = requireSession(id);
    switch (s.status) {
      case SessionStatus.ongoing:
        _finish(s, SessionStatus.completed, reason);
      case SessionStatus.requested:
        _finish(s, SessionStatus.cancelled, reason);
      default:
        break; // already finished: idempotent
    }
  }

  void review(User user, String id, int rating, String comment) {
    final s = requireOwned(user, id);
    if (s.status != SessionStatus.completed) {
      throw ApiError(409, 'invalid_state', 'Only completed consultations can be rated');
    }
    if (s.rating != null) throw ApiError(409, 'already_rated', 'Already rated');
    if (rating < 1 || rating > 5) {
      throw ApiError(400, 'invalid_rating', 'Rating must be between 1 and 5');
    }
    s.rating = rating;
    store.astrologers[s.astrologerId]!.addReview(Review(
      userName: user.name.split(' ').first,
      rating: rating,
      comment: comment.trim(),
      createdAt: DateTime.now(),
    ));
    store.scheduleSave();
    _notify(s);
  }

  // ------------------------------------------------------------------ chat

  Message postMessage(String sessionId, Sender sender, String text,
      {String? clientId}) {
    final s = requireSession(sessionId);
    if (s.status != SessionStatus.ongoing) {
      throw ApiError(409, 'invalid_state', 'Consultation is not active');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ApiError(400, 'empty', 'Message is empty');
    if (trimmed.length > 2000) throw ApiError(400, 'too_long', 'Message is too long');
    final m = Message(
      id: newId(6),
      sessionId: s.id,
      sender: sender,
      text: trimmed,
      clientId: clientId,
    );
    _deliver(s, m);

    if (sender == Sender.user && !hub.hasConsole(s.astrologerId)) {
      _botSay(s, _bot.reply(trimmed, store.users[s.userId]!));
    }
    return m;
  }

  void typing(String sessionId, Sender from) {
    final s = store.sessions[sessionId];
    if (s == null || s.status != SessionStatus.ongoing) return;
    final data = {'sessionId': s.id, 'sender': from.name};
    if (from == Sender.user) {
      hub.toAstrologer(s.astrologerId, 'typing', data);
    } else {
      hub.toUser(s.userId, 'typing', data);
    }
  }

  // ---------------------------------------------------------- connections

  void userConnected(String userId) {
    _disconnectTimers.remove('u:$userId')?.cancel();
  }

  void userDisconnected(String userId) {
    final s = store.activeSessionFor(userId);
    if (s == null) return;
    _disconnectTimers['u:$userId'] = Timer(config.disconnectGrace, () {
      _disconnectTimers.remove('u:$userId');
      if (!hub.isUserConnected(userId) && s.isActive) {
        end(s.id, 'user_disconnected');
      }
    });
  }

  /// [autoOnline]: the demo console brings an offline astrologer online when
  /// it connects. The astrologer app doesn't: there the astrologer decides.
  void astrologerConnected(String astrologerId, {bool autoOnline = true}) {
    _disconnectTimers.remove('a:$astrologerId')?.cancel();
    final a = store.astrologers[astrologerId];
    if (autoOnline && a != null && a.status == AstrologerStatus.offline) {
      _setStatus(a, AstrologerStatus.online);
    }
  }

  void astrologerDisconnected(String astrologerId) {
    _disconnectTimers['a:$astrologerId'] = Timer(config.disconnectGrace, () {
      _disconnectTimers.remove('a:$astrologerId');
      if (hub.hasConsole(astrologerId)) return;
      for (final s in store.sessions.values.where(
          (s) => s.astrologerId == astrologerId && s.isActive).toList()) {
        if (s.status == SessionStatus.ongoing) {
          end(s.id, 'astrologer_disconnected');
        } else {
          _finish(s, SessionStatus.rejected, 'astrologer_disconnected');
        }
      }
    });
  }

  /// The astrologer chooses to take consultations ("online") or not.
  void setAstrologerStatus(Astrologer a, AstrologerStatus status) {
    if (status == AstrologerStatus.busy) {
      throw ApiError(400, 'invalid_status', 'Status must be online or offline');
    }
    final active = store.sessions.values.any((s) =>
        s.astrologerId == a.id && s.status == SessionStatus.ongoing);
    if (active) {
      throw ApiError(409, 'session_active',
          'Finish your current consultation before changing availability.');
    }
    _setStatus(a, status);
  }

  /// Totals for the astrologer dashboard.
  Map<String, dynamic> astrologerStats(Astrologer a) {
    final done = store.sessions.values.where(
        (s) => s.astrologerId == a.id && s.status == SessionStatus.completed);
    final startOfDay = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    int earned(Iterable<Session> list) =>
        list.fold<int>(0, (sum, s) => sum + (s.cost * config.astrologerShare).floor());
    final today = done.where((s) => (s.endedAt ?? s.requestedAt).isAfter(startOfDay));
    return {
      'totalConsultations': done.length,
      'totalEarnings': earned(done),
      'todayConsultations': today.length,
      'todayEarnings': earned(today),
      'pendingRequests': store.sessions.values
          .where((s) => s.astrologerId == a.id && s.status == SessionStatus.requested)
          .length,
      'share': config.astrologerShare,
    };
  }

  List<Map<String, dynamic>> sessionsForAstrologer(String astrologerId) =>
      store.sessions.values
          .where((s) => s.astrologerId == astrologerId)
          .map(sessionJson)
          .toList()
        ..sort((a, b) =>
            (b['requestedAt'] as String).compareTo(a['requestedAt'] as String));

  /// Charges each started minute of every ongoing session; ends the session
  /// when the wallet can't cover the next one.
  void _billOngoing() {
    final now = DateTime.now();
    for (final s in store.sessions.values
        .where((s) => s.status == SessionStatus.ongoing && s.startedAt != null)
        .toList()) {
      final user = store.users[s.userId];
      if (user == null) continue;
      final elapsed = now.difference(s.startedAt!).inMicroseconds;
      final needed = (elapsed / config.minuteDuration.inMicroseconds).ceil();
      var charged = false;
      while (s.chargedMinutes < needed) {
        final a = store.astrologers[s.astrologerId]!;
        if (!wallet.charge(user, s.ratePerMinute,
            note: 'Consultation with ${a.name}: minute ${s.chargedMinutes + 1}',
            session: s)) {
          _finish(s, SessionStatus.completed, 'insufficient_balance');
          charged = false;
          break;
        }
        s.chargedMinutes++;
        charged = true;
      }
      if (charged) {
        store.scheduleSave();
        _notify(s); // carries the new paidUntil
      }
    }
  }

  // -------------------------------------------------------------- internals

  void _finish(Session s, SessionStatus status, String reason) {
    _cancelTimers(s.id);
    final wasOngoing = s.status == SessionStatus.ongoing;
    s.status = status;
    s.endReason = reason;
    s.endedAt = DateTime.now();
    final a = store.astrologers[s.astrologerId]!;
    if (wasOngoing) {
      a.totalConsultations++;
      _setStatus(a, AstrologerStatus.online);
      _system(s, 'Consultation ended');
    }
    store.scheduleSave();
    _notify(s);
  }

  void _notify(Session s) {
    final json = sessionJson(s);
    hub.toUser(s.userId, 'session.updated', json);
    hub.toAstrologer(s.astrologerId, 'session.updated', json);
  }

  void _deliver(Session s, Message m) {
    store.messagesOf(s.id).add(m);
    store.scheduleSave();
    final json = m.toJson();
    hub.toUser(s.userId, 'chat.message', json);
    hub.toAstrologer(s.astrologerId, 'chat.message', json);
  }

  void _system(Session s, String text) => _deliver(
      s, Message(id: newId(6), sessionId: s.id, sender: Sender.system, text: text));

  void _botSay(Session s, String text) {
    _after(s.id, const Duration(milliseconds: 600), () {
      if (s.status == SessionStatus.ongoing) typing(s.id, Sender.astrologer);
    });
    final jitter = Duration(milliseconds: _rand.nextInt(1200));
    _after(s.id, config.botTypingDelay + jitter, () {
      if (s.status != SessionStatus.ongoing) return;
      _deliver(s, Message(
          id: newId(6), sessionId: s.id, sender: Sender.astrologer, text: text));
    });
  }

  void _setStatus(Astrologer a, AstrologerStatus status) {
    if (a.status == status) return;
    a.status = status;
    store.scheduleSave();
    hub.broadcast('astrologer.status', {'astrologerId': a.id, 'status': status.name});
  }

  /// Flip a couple of astrologers between online/offline so presence
  /// updates are visible in the app.
  void _togglePresence() {
    for (final id in ['a8', 'a10']) {
      final a = store.astrologers[id];
      if (a == null || hub.hasConsole(id) || a.status == AstrologerStatus.busy) {
        continue;
      }
      if (store.sessions.values.any((s) => s.astrologerId == id && s.isActive)) {
        continue;
      }
      if (_rand.nextBool()) {
        _setStatus(a, a.status == AstrologerStatus.online
            ? AstrologerStatus.offline
            : AstrologerStatus.online);
      }
    }
  }

  void _after(String sessionId, Duration d, void Function() fn) {
    late final Timer t;
    t = Timer(d, () {
      _timers[sessionId]?.remove(t);
      fn();
    });
    _timers.putIfAbsent(sessionId, () => []).add(t);
  }

  void _cancelTimers(String sessionId) {
    for (final t in _timers.remove(sessionId) ?? const <Timer>[]) {
      t.cancel();
    }
  }
}

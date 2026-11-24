import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'models.dart';
import 'seed.dart';

/// a1 -> 9100000001 ... a12 -> 9100000012.
String defaultAstrologerPhone(String astrologerId) =>
    '91000000${astrologerId.replaceAll(RegExp(r'\D'), '').padLeft(2, '0')}';

final _rand = Random.secure();

String newId([int bytes = 8]) =>
    List.generate(bytes, (_) => _rand.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();

/// In-memory data store, optionally persisted to a JSON file so users,
/// sessions and history survive restarts.
class Store {
  Store({this.file});

  final File? file;

  final users = <String, User>{};
  final tokens = <String, String>{}; // token -> userId
  final astrologerTokens = <String, String>{}; // token -> astrologerId
  final astrologers = <String, Astrologer>{};
  final sessions = <String, Session>{};
  final messages = <String, List<Message>>{}; // sessionId -> messages
  final transactions = <WalletTxn>[];

  Timer? _saveTimer;

  Future<void> load() async {
    final f = file;
    if (f != null && await f.exists()) {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      for (final u in (j['users'] as List)) {
        final user = User.fromJson(u as Map<String, dynamic>);
        users[user.id] = user;
      }
      tokens.addAll((j['tokens'] as Map).cast<String, String>());
      astrologerTokens
          .addAll(((j['astrologerTokens'] as Map?) ?? const {}).cast<String, String>());
      for (final a in (j['astrologers'] as List)) {
        final astro = Astrologer.fromJson(a as Map<String, dynamic>);
        astrologers[astro.id] = astro;
      }
      for (final s in (j['sessions'] as List)) {
        final session = Session.fromJson(s as Map<String, dynamic>);
        sessions[session.id] = session;
      }
      for (final t in ((j['transactions'] as List?) ?? const [])) {
        transactions.add(WalletTxn.fromJson(t as Map<String, dynamic>));
      }
      (j['messages'] as Map).forEach((k, v) {
        messages[k as String] = (v as List)
            .map((m) => Message.fromJson(m as Map<String, dynamic>))
            .toList();
      });
    }
    if (astrologers.isEmpty) {
      for (final a in seedAstrologers()) {
        astrologers[a.id] = a;
      }
    }
    // Databases saved before astrologer logins existed have no phone numbers.
    for (final a in astrologers.values.where((a) => a.phone.isEmpty)) {
      a.phone = defaultAstrologerPhone(a.id);
    }
    // Anything left in flight by a previous run can't be resumed.
    for (final s in sessions.values.where((s) => s.isActive)) {
      if (s.status == SessionStatus.ongoing) {
        astrologers[s.astrologerId]?.status = AstrologerStatus.online;
      }
      s.endedAt = DateTime.now();
      s.endReason = 'server_restart';
      s.status = s.status == SessionStatus.ongoing
          ? SessionStatus.completed
          : SessionStatus.cancelled;
    }
    scheduleSave();
  }

  User? userByPhone(String phone) {
    for (final u in users.values) {
      if (u.phone == phone) return u;
    }
    return null;
  }

  User? userByToken(String token) {
    final id = tokens[token];
    return id == null ? null : users[id];
  }

  Astrologer? astrologerByPhone(String phone) {
    for (final a in astrologers.values) {
      if (a.phone == phone) return a;
    }
    return null;
  }

  Astrologer? astrologerByToken(String token) {
    final id = astrologerTokens[token];
    return id == null ? null : astrologers[id];
  }

  String issueAstrologerToken(Astrologer a) {
    final t = newId(24);
    astrologerTokens[t] = a.id;
    scheduleSave();
    return t;
  }

  String issueToken(User user) {
    final t = newId(24);
    tokens[t] = user.id;
    scheduleSave();
    return t;
  }

  Session? activeSessionFor(String userId) {
    for (final s in sessions.values) {
      if (s.userId == userId && s.isActive) return s;
    }
    return null;
  }

  List<Message> messagesOf(String sessionId) =>
      messages.putIfAbsent(sessionId, () => []);

  void scheduleSave() {
    if (file == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), save);
  }

  Future<void> save() async {
    final f = file;
    if (f == null) return;
    await f.parent.create(recursive: true);
    final data = {
      'users': users.values.map((u) => u.toJson()).toList(),
      'tokens': tokens,
      'astrologerTokens': astrologerTokens,
      'astrologers': astrologers.values.map((a) => a.toStoreJson()).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'sessions': sessions.values.map((s) => s.toJson()).toList(),
      'messages': messages.map(
          (k, v) => MapEntry(k, v.map((m) => m.toJson()).toList())),
    };
    await f.writeAsString(const JsonEncoder.withIndent(' ').convert(data));
  }
}

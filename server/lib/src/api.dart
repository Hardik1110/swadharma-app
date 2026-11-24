import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'consultation_service.dart';
import 'firebase_auth.dart';
import 'hub.dart';
import 'models.dart';
import 'seed.dart';
import 'store.dart';

class _Otp {
  _Otp(this.code, this.purpose, this.sentAt);
  final String code;
  final String purpose;
  final DateTime sentAt;
  int attempts = 0;

  bool get expired => DateTime.now().difference(sentAt) > Api.otpTtl;
}

class Api {
  Api(this.store, this.hub, this.consultations,
      {this.devMode = true, this.publicDir, this.firebase, this.enableConsole = true});

  static const otpTtl = Duration(minutes: 5);
  static const otpResend = Duration(seconds: 30);
  static const otpMaxAttempts = 5;

  final Store store;
  final Hub hub;
  final ConsultationService consultations;

  /// Returns the OTP in the send-otp response so the demo works without SMS.
  final bool devMode;

  /// Directory holding console.html.
  final String? publicDir;

  /// The browser astrologer console (and its unauthenticated endpoints) are a
  /// demo aid. Turn off on a public deployment if you don't want strangers
  /// able to accept consultation requests.
  final bool enableConsole;

  /// When set, login uses Firebase phone auth (real SMS) and the demo OTP
  /// endpoints are disabled.
  final FirebaseTokenVerifier? firebase;

  final _otps = <String, _Otp>{};
  final _rand = Random.secure();

  Handler get handler {
    final r = Router()
      ..get('/health', (Request _) => _json({'ok': true}))
      ..get('/config', (Request _) => _json({
            'callsEnabled': consultations.config.callsEnabled,
            'phoneAuth': firebase != null ? 'firebase' : 'demo',
            'expertise': expertiseTags,
          }))
      ..post('/auth/check-phone', _checkPhone)
      ..post('/auth/firebase', _firebaseLogin)
      ..post('/auth/send-otp', _sendOtp)
      ..post('/auth/verify-otp', _verifyOtp)
      ..post('/auth/logout', _logout)
      ..get('/me', (Request req) {
        final astro = store.astrologerByToken(_token(req));
        if (astro != null) return _json(_astrologerUserJson(astro));
        return _auth((req, u) => _json(u.toJson()))(req);
      })
      ..put('/me', _auth(_updateMe))
      ..get('/wallet', _auth((req, u) => _json(consultations.wallet.summary(u))))
      ..post('/wallet/topup', _auth(_topUp))
      ..get('/astrologers', _auth(_listAstrologers))
      ..get('/astrologers/<id>', _auth(_getAstrologer))
      ..post('/sessions', _auth(_createSession))
      ..get('/sessions', _auth(_listSessions))
      ..get('/sessions/<id>', _auth((req, u) =>
          _json(consultations.sessionJson(
              consultations.requireOwned(u, req.params['id']!)))))
      ..get('/sessions/<id>/messages', _auth((req, u) {
        final s = consultations.requireOwned(u, req.params['id']!);
        return _json(store.messagesOf(s.id).map((m) => m.toJson()).toList());
      }))
      ..post('/sessions/<id>/cancel', _auth((req, u) {
        consultations.cancel(u, req.params['id']!);
        return _sessionResponse(req.params['id']!);
      }))
      ..post('/sessions/<id>/end', _auth((req, u) async {
        final s = consultations.requireOwned(u, req.params['id']!);
        final body = await _body(req);
        consultations.end(s.id, (body['reason'] as String?) ?? 'user_ended');
        return _sessionResponse(s.id);
      }))
      ..post('/sessions/<id>/messages', _auth((req, u) async {
        final s = consultations.requireOwned(u, req.params['id']!);
        final body = await _body(req);
        final m = consultations.postMessage(
            s.id, Sender.user, body['text'] as String? ?? '',
            clientId: body['clientId'] as String?);
        return _json(m.toJson(), 201);
      }))
      ..post('/sessions/<id>/review', _auth((req, u) async {
        final body = await _body(req);
        consultations.review(u, req.params['id']!,
            (body['rating'] as num?)?.toInt() ?? 0, body['comment'] as String? ?? '');
        return _sessionResponse(req.params['id']!);
      }))
      // ---- astrologer app (token from an astrologer login) ----
      ..get('/astrologer/me', _authAstro((req, a) => _json({
            'profile': a.toJson(),
            'stats': consultations.astrologerStats(a),
          })))
      ..put('/astrologer/status', _authAstro(_setAstrologerStatus))
      ..get('/astrologer/sessions', _authAstro((req, a) =>
          _json(consultations.sessionsForAstrologer(a.id))))
      ..get('/astrologer/sessions/<id>', _authAstro((req, a) =>
          _astroSessionResponse(a, req.params['id']!)))
      ..get('/astrologer/sessions/<id>/messages', _authAstro((req, a) {
        final s = _astroOwned(a, req.params['id']!);
        return _json(store.messagesOf(s.id).map((m) => m.toJson()).toList());
      }))
      ..post('/astrologer/sessions/<id>/accept', _authAstro((req, a) {
        consultations.accept(_astroOwned(a, req.params['id']!).id);
        return _astroSessionResponse(a, req.params['id']!);
      }))
      ..post('/astrologer/sessions/<id>/reject', _authAstro((req, a) {
        consultations.reject(_astroOwned(a, req.params['id']!).id);
        return _astroSessionResponse(a, req.params['id']!);
      }))
      ..post('/astrologer/sessions/<id>/end', _authAstro((req, a) {
        consultations.end(_astroOwned(a, req.params['id']!).id, 'astrologer_ended');
        return _astroSessionResponse(a, req.params['id']!);
      }))
      ..post('/astrologer/sessions/<id>/messages', _authAstro((req, a) async {
        final s = _astroOwned(a, req.params['id']!);
        final body = await _body(req);
        final m = consultations.postMessage(
            s.id, Sender.astrologer, body['text'] as String? ?? '',
            clientId: body['clientId'] as String?);
        return _json(m.toJson(), 201);
      }))
      ..get('/ws', _ws)
      // ---- astrologer console (demo only, unauthenticated) ----
      ..get('/console/astrologers', (Request _) => _json(
          store.astrologers.values.map((a) => a.toSummaryJson()).toList()))
      ..get('/console/astrologers/<id>/sessions', (Request req) =>
          _json(consultations.sessionsForAstrologer(req.params['id']!)))
      ..get('/console/sessions/<id>/messages', (Request req) => _json(store
          .messagesOf(consultations.requireSession(req.params['id']!).id)
          .map((m) => m.toJson())
          .toList()))
      ..post('/console/sessions/<id>/accept', (Request req) {
        consultations.accept(req.params['id']!);
        return _sessionResponse(req.params['id']!);
      })
      ..post('/console/sessions/<id>/reject', (Request req) {
        consultations.reject(req.params['id']!);
        return _sessionResponse(req.params['id']!);
      })
      ..post('/console/sessions/<id>/end', (Request req) {
        consultations.end(req.params['id']!, 'astrologer_ended');
        return _sessionResponse(req.params['id']!);
      });

    final dir = publicDir;
    if (dir != null) {
      // Pre-recorded clip the console can play as a "demo astrologer".
      r.mount('/demo/', createStaticHandler('$dir/demo'));
      r.get('/console', (Request req) => createFileHandler(
            '$dir/console.html',
            url: 'console',
          )(req));
    }

    return const Pipeline()
        .addMiddleware(_consoleGuard())
        .addMiddleware(_logRequests())
        .addMiddleware(_errors())
        .addHandler(r.call);
  }

  // ------------------------------------------------------------------ auth

  Future<Response> _sendOtp(Request req) async {
    final body = await _body(req);
    _demoOnly();
    final phone = _phone(body['phone']);
    final purpose = _purpose(body);
    _checkPurpose(phone, purpose);
    final prev = _otps[phone];
    if (prev != null && DateTime.now().difference(prev.sentAt) < otpResend) {
      final wait = otpResend - DateTime.now().difference(prev.sentAt);
      throw ApiError(429, 'too_many_requests',
          'Please wait ${wait.inSeconds + 1}s before requesting a new OTP');
    }
    final code = (_rand.nextInt(900000) + 100000).toString();
    _otps[phone] = _Otp(code, purpose, DateTime.now());
    stdout.writeln('[otp] $phone -> $code');
    return _json({
      'expiresIn': otpTtl.inSeconds,
      'resendIn': otpResend.inSeconds,
      if (devMode) 'devOtp': code,
    });
  }

  /// Demo OTPs would bypass SMS verification, so they are off in Firebase mode.
  void _demoOnly() {
    if (firebase != null) {
      throw ApiError(400, 'use_firebase', 'This server uses Firebase phone login');
    }
  }

  /// Login needs an existing account; sign-up needs a new number.
  /// 'login', 'signup' or 'astrologer' (the astrologer app).
  String _purpose(Map<String, dynamic> body) => switch (body['purpose']) {
        'signup' => 'signup',
        'astrologer' => 'astrologer',
        _ => 'login',
      };

  void _checkPurpose(String phone, String purpose) {
    if (purpose == 'astrologer') {
      if (store.astrologerByPhone(phone) == null) {
        throw ApiError(404, 'astrologer_not_found',
            'No astrologer is registered with this number.');
      }
      return;
    }
    final existing = store.userByPhone(phone);
    if (purpose == 'login' && existing == null) {
      throw ApiError(404, 'account_not_found',
          'No account found for this number. Please sign up.');
    }
    if (purpose == 'signup' && existing != null) {
      throw ApiError(409, 'account_exists',
          'An account already exists for this number. Please log in.');
    }
  }

  /// Called before an SMS is sent, so we never text a number that is on the
  /// wrong flow.
  Future<Response> _checkPhone(Request req) async {
    final body = await _body(req);
    _checkPurpose(_phone(body['phone']), _purpose(body));
    return _json({'ok': true});
  }

  Future<Response> _firebaseLogin(Request req) async {
    final verifier = firebase;
    if (verifier == null) {
      throw ApiError(400, 'firebase_disabled', 'Firebase login is not enabled on this server');
    }
    final body = await _body(req);
    final identity = await verifier.verify(body['idToken'] as String? ?? '');
    final purpose = _purpose(body);
    _checkPurpose(identity.phone, purpose);
    if (purpose == 'astrologer') return _astrologerSession(identity.phone);

    var user = store.userByPhone(identity.phone);
    final isNew = user == null;
    if (user == null) {
      final name = (body['name'] as String? ?? '').trim();
      if (name.length < 2) {
        throw ApiError(400, 'invalid_name', 'Please enter your full name');
      }
      user = User(id: newId(6), phone: identity.phone, name: name);
      store.users[user.id] = user;
    }
    consultations.wallet.ensureInitialized(user);
    final token = store.issueToken(user);
    return _json({'token': token, 'user': user.toJson(), 'isNewUser': isNew});
  }

  Future<Response> _verifyOtp(Request req) async {
    _demoOnly();
    final body = await _body(req);
    final phone = _phone(body['phone']);
    final otp = (body['otp'] as String? ?? '').trim();
    final entry = _otps[phone];
    if (entry == null || entry.expired) {
      _otps.remove(phone);
      throw ApiError(400, 'otp_expired', 'OTP expired. Please request a new one.');
    }
    if (entry.code != otp) {
      entry.attempts++;
      if (entry.attempts >= otpMaxAttempts) {
        _otps.remove(phone);
        throw ApiError(400, 'otp_locked',
            'Too many wrong attempts. Please request a new OTP.');
      }
      throw ApiError(400, 'otp_invalid',
          'Incorrect OTP. ${otpMaxAttempts - entry.attempts} attempts left.');
    }
    _otps.remove(phone);
    if (entry.purpose == 'astrologer') return _astrologerSession(phone);

    var user = store.userByPhone(phone);
    final isNew = user == null;
    if (user == null) {
      user = User(id: newId(6), phone: phone, name: (body['name'] as String? ?? '').trim());
      store.users[user.id] = user;
    }
    consultations.wallet.ensureInitialized(user);
    final token = store.issueToken(user);
    return _json({'token': token, 'user': user.toJson(), 'isNewUser': isNew});
  }

  /// Signs an astrologer in (after the number was verified) and brings them
  /// online so they can start taking requests.
  Response _astrologerSession(String phone) {
    final a = store.astrologerByPhone(phone)!;
    if (a.status == AstrologerStatus.offline) {
      consultations.setAstrologerStatus(a, AstrologerStatus.online);
    }
    final token = store.issueAstrologerToken(a);
    return _json({
      'token': token,
      'role': 'astrologer',
      'user': _astrologerUserJson(a),
      'isNewUser': false,
    });
  }

  /// An astrologer in the shape of the app's signed-in user.
  Map<String, dynamic> _astrologerUserJson(Astrologer a) => {
        'id': a.id,
        'phone': a.phone,
        'name': a.name,
        'role': 'astrologer',
        'astrologerId': a.id,
        'avatarUrl': a.avatarUrl,
        'gender': '',
        'dob': '',
        'birthTime': '',
        'birthPlace': '',
        'profileComplete': true,
        'balance': 0,
      };

  Response _logout(Request req) {
    final t = _token(req);
    if (store.tokens.remove(t) == null && store.astrologerTokens.remove(t) == null) {
      throw ApiError(401, 'unauthorized', 'Session expired. Please log in again.');
    }
    store.scheduleSave();
    return _json({'ok': true});
  }

  Future<Response> _updateMe(Request req, User u) async {
    final b = await _body(req);
    String field(String k, {int max = 80}) {
      final v = (b[k] as String? ?? '').trim();
      if (v.length > max) throw ApiError(400, 'invalid_$k', '$k is too long');
      return v;
    }

    final name = field('name');
    final dob = field('dob', max: 10);
    final time = field('birthTime', max: 5);
    final place = field('birthPlace', max: 120);
    final gender = field('gender', max: 20);
    if (name.length < 2) throw ApiError(400, 'invalid_name', 'Please enter your full name');
    final d = DateTime.tryParse(dob);
    if (d == null || d.isAfter(DateTime.now()) || d.year < 1900) {
      throw ApiError(400, 'invalid_dob', 'Please enter a valid date of birth');
    }
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
      throw ApiError(400, 'invalid_birth_time', 'Please enter a valid birth time');
    }
    if (place.length < 2) {
      throw ApiError(400, 'invalid_birth_place', 'Please enter your birth place');
    }
    u
      ..name = name
      ..dob = dob
      ..birthTime = time
      ..birthPlace = place
      ..gender = gender;
    store.scheduleSave();
    return _json(u.toJson());
  }

  Future<Response> _topUp(Request req, User u) async {
    final body = await _body(req);
    final amount = (body['amount'] as num?)?.toInt() ?? 0;
    consultations.wallet.topUp(u, amount);
    return _json(consultations.wallet.summary(u));
  }

  // ----------------------------------------------------------- astrologers

  Response _listAstrologers(Request req, User _) {
    final p = req.url.queryParameters;
    final q = (p['q'] ?? '').trim().toLowerCase();
    final expertise = p['expertise'] ?? '';
    final language = p['language'] ?? '';
    final onlineOnly = p['onlineOnly'] == 'true';
    final sort = p['sort'] ?? 'recommended';

    var list = store.astrologers.values.where((a) {
      if (onlineOnly && a.status != AstrologerStatus.online) return false;
      if (expertise.isNotEmpty && !a.expertise.contains(expertise)) return false;
      if (language.isNotEmpty && !a.languages.contains(language)) return false;
      if (q.isEmpty) return true;
      return a.name.toLowerCase().contains(q) ||
          a.expertise.any((e) => e.toLowerCase().contains(q)) ||
          a.languages.any((l) => l.toLowerCase().contains(q));
    }).toList();

    int statusRank(Astrologer a) => a.status.index; // online, busy, offline
    list.sort(switch (sort) {
      'rating' => (a, b) => b.rating.compareTo(a.rating),
      'experience' => (a, b) => b.experienceYears.compareTo(a.experienceYears),
      'price_low' => (a, b) => a.pricing['chat']!.compareTo(b.pricing['chat']!),
      'price_high' => (a, b) => b.pricing['chat']!.compareTo(a.pricing['chat']!),
      _ => (a, b) {
          final s = statusRank(a).compareTo(statusRank(b));
          return s != 0 ? s : b.rating.compareTo(a.rating);
        },
    });
    return _json(list.map((a) => a.toSummaryJson()).toList());
  }

  Response _getAstrologer(Request req, User _) {
    final a = store.astrologers[req.params['id']];
    if (a == null) throw ApiError(404, 'not_found', 'Astrologer not found');
    return _json(a.toJson());
  }

  // ------------------------------------------------------------- sessions

  Future<Response> _createSession(Request req, User u) async {
    final b = await _body(req);
    final typeName = b['type'] as String? ?? '';
    final type = SessionType.values.where((t) => t.name == typeName).firstOrNull;
    if (type == null) {
      throw ApiError(400, 'invalid_type', 'type must be chat, voice or video');
    }
    final s = consultations.create(u, b['astrologerId'] as String? ?? '', type);
    return _json(consultations.sessionJson(s), 201);
  }

  Response _listSessions(Request req, User u) {
    final list = store.sessions.values.where((s) => s.userId == u.id).toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return _json(list.map(consultations.sessionJson).toList());
  }

  Response _sessionResponse(String id) =>
      _json(consultations.sessionJson(consultations.requireSession(id)));

  // ------------------------------------------------------------ websocket

  /// `/ws?token=...` for consumers, `/ws?astrologerId=...` for the console.
  FutureOr<Response> _ws(Request req) {
    final p = req.url.queryParameters;
    final user = store.userByToken(p['token'] ?? '');
    final tokenAstrologer = store.astrologerByToken(p['token'] ?? '');
    // Astrologer app: identified by token. Demo console: by id.
    final astrologerId = tokenAstrologer?.id ?? p['astrologerId'];
    if (user == null &&
        (astrologerId == null || !store.astrologers.containsKey(astrologerId))) {
      throw ApiError(401, 'unauthorized', 'Invalid or missing token');
    }
    return webSocketHandler((WebSocketChannel ch, String? _) {
      if (user != null) {
        hub.addUser(user.id, ch);
        consultations.userConnected(user.id);
      } else {
        hub.addAstrologer(astrologerId!, ch);
        consultations.astrologerConnected(astrologerId,
            autoOnline: tokenAstrologer == null);
      }
      Hub.send(ch, 'ready', {'serverTime': DateTime.now().toUtc().toIso8601String()});

      ch.stream.listen(
        (raw) => _onSocketMessage(ch, raw, user, astrologerId),
        onDone: () {
          if (user != null) {
            if (hub.removeUser(user.id, ch)) consultations.userDisconnected(user.id);
          } else if (hub.removeAstrologer(astrologerId!, ch)) {
            consultations.astrologerDisconnected(astrologerId);
          }
        },
        onError: (_) {},
      );
    }, pingInterval: const Duration(seconds: 20))(req);
  }

  void _onSocketMessage(
      WebSocketChannel ch, Object? raw, User? user, String? astrologerId) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      Hub.send(ch, 'error', {'message': 'Malformed message'});
      return;
    }
    final data = (msg['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final sessionId = data['sessionId'] as String? ?? '';
    final clientId = data['clientId'] as String?;
    try {
      switch (msg['type']) {
        case 'ping':
          Hub.send(ch, 'pong', null);
        case 'chat.send':
          final s = _socketSession(sessionId, user, astrologerId);
          consultations.postMessage(s.id,
              user != null ? Sender.user : Sender.astrologer,
              data['text'] as String? ?? '',
              clientId: clientId);
        case 'typing':
          final s = _socketSession(sessionId, user, astrologerId);
          consultations.typing(s.id, user != null ? Sender.user : Sender.astrologer);
        default:
          Hub.send(ch, 'error', {'message': 'Unknown type ${msg['type']}'});
      }
    } on ApiError catch (e) {
      Hub.send(ch, 'error', {
        'code': e.code,
        'message': e.message,
        'sessionId': sessionId,
        'clientId': ?clientId,
      });
    }
  }

  Session _socketSession(String id, User? user, String? astrologerId) {
    final s = consultations.requireSession(id);
    if ((user != null && s.userId != user.id) ||
        (user == null && s.astrologerId != astrologerId)) {
      throw ApiError(403, 'forbidden', 'Not your consultation');
    }
    return s;
  }

  // ------------------------------------------------------ astrologer app

  Future<Response> _setAstrologerStatus(Request req, Astrologer a) async {
    final body = await _body(req);
    final status = switch (body['status']) {
      'online' => AstrologerStatus.online,
      'offline' => AstrologerStatus.offline,
      _ => throw ApiError(400, 'invalid_status', 'Status must be online or offline'),
    };
    consultations.setAstrologerStatus(a, status);
    return _json({'status': a.status.name});
  }

  Session _astroOwned(Astrologer a, String id) {
    final s = consultations.requireSession(id);
    if (s.astrologerId != a.id) {
      throw ApiError(404, 'not_found', 'Consultation not found');
    }
    return s;
  }

  Response _astroSessionResponse(Astrologer a, String id) =>
      _json(consultations.sessionJson(_astroOwned(a, id)));

  // -------------------------------------------------------------- helpers

  Handler _authAstro(FutureOr<Response> Function(Request, Astrologer) fn) => (req) {
        final a = store.astrologerByToken(_token(req));
        if (a == null) {
          if (store.userByToken(_token(req)) != null) {
            throw ApiError(403, 'wrong_role', 'This is a consumer account.');
          }
          throw ApiError(401, 'unauthorized', 'Session expired. Please log in again.');
        }
        return fn(req, a);
      };

  Handler _auth(FutureOr<Response> Function(Request, User) fn) => (req) {
        final user = store.userByToken(_token(req));
        if (user == null) {
          if (store.astrologerByToken(_token(req)) != null) {
            throw ApiError(403, 'wrong_role', 'This is an astrologer account.');
          }
          throw ApiError(401, 'unauthorized', 'Session expired. Please log in again.');
        }
        consultations.wallet.ensureInitialized(user); // accounts created before wallets
        return fn(req, user);
      };

  String _token(Request req) {
    final h = req.headers['authorization'] ?? '';
    return h.startsWith('Bearer ') ? h.substring(7) : '';
  }

  String _phone(Object? v) {
    final phone = (v as String? ?? '').replaceAll(RegExp(r'\D'), '');
    if (phone.length != 10) {
      throw ApiError(400, 'invalid_phone', 'Enter a valid 10-digit mobile number');
    }
    return phone;
  }

  Future<Map<String, dynamic>> _body(Request req) async {
    final text = await req.readAsString();
    if (text.isEmpty) return {};
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw ApiError(400, 'bad_json', 'Request body must be a JSON object');
    }
  }

  static Response _json(Object? data, [int status = 200]) => Response(status,
      body: jsonEncode(data), headers: {'content-type': 'application/json'});

  Middleware _errors() => (inner) => (req) async {
        try {
          return await inner(req);
        } on HijackException {
          rethrow; // WebSocket upgrade
        } on ApiError catch (e) {
          return _json({
            'error': {'code': e.code, 'message': e.message}
          }, e.status);
        } catch (e, st) {
          stderr.writeln('Unhandled error: $e\n$st');
          return _json({
            'error': {'code': 'internal', 'message': 'Something went wrong'}
          }, 500);
        }
      };

  /// With [enableConsole] off, the console page, its API, its demo clip and
  /// id-only WebSocket connections all behave as if they don't exist.
  Middleware _consoleGuard() => (inner) => (req) {
        if (enableConsole) return inner(req);
        final path = req.url.path;
        final q = req.url.queryParameters;
        final consoleSocket = path == 'ws' && q.containsKey('astrologerId') && !q.containsKey('token');
        if (path == 'console' || path.startsWith('console/') || path.startsWith('demo/') || consoleSocket) {
          return Response.notFound(jsonEncode({
            'error': {'code': 'not_found', 'message': 'Not found'}
          }), headers: {'content-type': 'application/json'});
        }
        return inner(req);
      };

  Middleware _logRequests() => (inner) => (req) async {
        final sw = Stopwatch()..start();
        final res = await inner(req);
        if (req.url.path != 'ws') {
          stdout.writeln(
              '${req.method} /${req.url} -> ${res.statusCode} (${sw.elapsedMilliseconds}ms)');
        }
        return res;
      };
}

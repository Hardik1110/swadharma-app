import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:astro_server/astro_server.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  late Store store;
  late HttpServer server;
  late ConsultationService consultations;
  late String base;

  setUp(() async {
    store = Store();
    await store.load();
    final hub = Hub();
    consultations = ConsultationService(
      store,
      hub,
      const ConsultationConfig(
        agoraAppId: 'test-app',
        botAcceptDelay: Duration(milliseconds: 100),
        botTypingDelay: Duration(milliseconds: 50),
        requestTimeout: Duration(seconds: 10),
        simulatePresence: false,
        // One "minute" is one second so billing can be tested quickly.
        minuteDuration: Duration(seconds: 1),
        billingTick: Duration(milliseconds: 100),
      ),
    );
    server = await io.serve(Api(store, hub, consultations).handler, 'localhost', 0);
    base = 'http://localhost:${server.port}';
  });

  tearDown(() async {
    consultations.dispose();
    await server.close(force: true);
  });

  Future<(int, dynamic)> call(String method, String path, {Object? body, String? token}) async {
    final req = http.Request(method, Uri.parse('$base$path'));
    if (token != null) req.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final res = await http.Response.fromStream(await req.send());
    return (res.statusCode, jsonDecode(res.body));
  }

  Future<String> readyUser(String phone) async {
    final (_, otp) = await call('POST', '/auth/send-otp', body: {'phone': phone, 'purpose': 'signup'});
    final (_, res) = await call('POST', '/auth/verify-otp',
        body: {'phone': phone, 'otp': otp['devOtp'], 'name': 'Asha Verma'});
    final token = res['token'] as String;
    await call('PUT', '/me', token: token, body: {
      'name': 'Asha Verma',
      'dob': '1995-08-15',
      'birthTime': '06:30',
      'birthPlace': 'Pune',
    });
    return token;
  }

  Map<String, dynamic> body(String astro, String type) => {'astrologerId': astro, 'type': type};

  test('new accounts get a welcome bonus', () async {
    final token = await readyUser('9000000101');
    final (status, w) = await call('GET', '/wallet', token: token);
    expect(status, 200);
    expect(w['balance'], 100);
    final txns = w['transactions'] as List;
    expect(txns.single['type'], 'bonus');
    expect(txns.single['amount'], 100);
    expect(txns.single['balanceAfter'], 100);
  });

  test('top-ups are validated, recorded and pushed live', () async {
    final token = await readyUser('9000000102');
    final ws = IOWebSocketChannel.connect(Uri.parse('ws://localhost:${server.port}/ws?token=$token'));
    final events = ws.stream
        .map((e) => jsonDecode(e as String) as Map<String, dynamic>)
        .asBroadcastStream();
    await ws.ready;

    for (final bad in [5, 20000, 0]) {
      final (s, r) = await call('POST', '/wallet/topup', token: token, body: {'amount': bad});
      expect(s, 400, reason: '$bad');
      expect(r['error']['code'], 'invalid_amount');
    }

    final pushed = events.firstWhere((e) => e['type'] == 'wallet.updated');
    final (s, w) = await call('POST', '/wallet/topup', token: token, body: {'amount': 500});
    expect(s, 200);
    expect(w['balance'], 600);
    expect((await pushed)['data']['balance'], 600);
    expect((w['transactions'] as List).first['type'], 'topup');
    await ws.sink.close();
  });

  test('booking needs at least one minute of balance', () async {
    final token = await readyUser('9000000103');
    store.userByToken(token)!.balance = 10; // a1 chat costs 25/min
    final (status, res) = await call('POST', '/sessions', token: token, body: body('a1', 'chat'));
    expect(status, 402);
    expect(res['error']['code'], 'insufficient_balance');
    expect(res['error']['message'], contains('add money'));
  });

  test('first minute is charged on accept, then every started minute', () async {
    final token = await readyUser('9000000104');
    final user = store.userByToken(token)!;
    final (_, created) = await call('POST', '/sessions', token: token, body: body('a1', 'chat'));
    final id = created['id'] as String;

    // Nothing is charged while the request is only waiting.
    expect(user.balance, 100);

    await Future<void>.delayed(const Duration(milliseconds: 450)); // bot accepted
    var (_, s) = await call('GET', '/sessions/$id', token: token);
    expect(s['status'], 'ongoing');
    expect(s['chargedMinutes'], 1);
    expect(user.balance, 75);
    expect(s['paidUntil'], isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    (_, s) = await call('GET', '/sessions/$id', token: token);
    expect(s['chargedMinutes'], 2);
    expect(user.balance, 50);

    final (_, ended) = await call('POST', '/sessions/$id/end', token: token);
    expect(ended['status'], 'completed');
    expect(ended['cost'], 50);
    expect(ended['earning'], 35); // 70% share

    final (_, w) = await call('GET', '/wallet', token: token);
    final charges = (w['transactions'] as List).where((t) => t['type'] == 'charge').toList();
    expect(charges.length, 2);
    expect(charges.first['astrologerName'], 'Pt. Raghav Sharma');
    expect(charges.first['sessionId'], id);
  });

  test('session ends by itself when the wallet runs dry', () async {
    final token = await readyUser('9000000105');
    final user = store.userByToken(token)!;
    user.balance = 50; // exactly two minutes at 25/min
    final (_, created) = await call('POST', '/sessions', token: token, body: body('a1', 'chat'));
    final id = created['id'] as String;

    await Future<void>.delayed(const Duration(milliseconds: 3600));
    final (_, s) = await call('GET', '/sessions/$id', token: token);
    expect(s['status'], 'completed');
    expect(s['endReason'], 'insufficient_balance');
    expect(s['cost'], 50);
    expect(user.balance, 0);
  });

  test('accept is refused if the balance dropped after the request', () async {
    final token = await readyUser('9000000106');
    final user = store.userByToken(token)!;
    // A person is on the console, so the bot will not auto-accept.
    final console = IOWebSocketChannel.connect(
        Uri.parse('ws://localhost:${server.port}/ws?astrologerId=a4'));
    await console.ready;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final (_, created) = await call('POST', '/sessions', token: token, body: body('a4', 'chat'));
    user.balance = 0;

    final (_, res) = await call('POST', '/console/sessions/${created['id']}/accept');
    expect(res['status'], 'rejected');
    expect(res['endReason'], 'insufficient_balance');
    await console.sink.close();
  });

  test('legacy accounts receive the bonus once', () async {
    final token = await readyUser('9000000107');
    final user = store.userByToken(token)!;
    // Simulate an account saved before wallets existed.
    user
      ..walletInitialized = false
      ..balance = 0;
    store.transactions.removeWhere((t) => t.userId == user.id);

    await call('GET', '/wallet', token: token);
    await call('GET', '/wallet', token: token);
    expect(user.balance, 100);
    expect(store.transactions.where((t) => t.userId == user.id).length, 1);
  });
}

// End-to-end contract check: the app's real API client and models against a
// live server, with a customer and an astrologer going through a whole
// consultation. Skipped unless a server is given:
//
//   cd server && PORT=8788 DATA_FILE="" AGORA_APP_ID=demo dart run bin/server.dart
//   LIVE_SERVER=http://localhost:8788 flutter test test/contract
//
// Needs a demo-login server (no FIREBASE_PROJECT_ID).
import 'dart:io';
import 'dart:math';

import 'package:astro_connect/core/errors/app_exception.dart';
import 'package:astro_connect/core/network/api_client.dart';
import 'package:astro_connect/core/network/socket_client.dart';
import 'package:astro_connect/features/astrologers/domain/astrologer.dart';
import 'package:astro_connect/features/auth/domain/user.dart';
import 'package:astro_connect/features/consultation/domain/chat_message.dart';
import 'package:astro_connect/features/consultation/domain/consultation.dart';
import 'package:astro_connect/features/desk/domain/desk.dart';
import 'package:astro_connect/features/wallet/domain/wallet.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

ApiClient _client(String base, [String? token]) => ApiClient(Dio(BaseOptions(
      baseUrl: base,
      contentType: 'application/json',
      headers: {'Authorization': ?(token == null ? null : 'Bearer $token')},
    )));

Uri _ws(String base, String token) {
  final u = Uri.parse(base);
  return u.replace(scheme: 'ws', path: '/ws', queryParameters: {'token': token});
}

/// First event of [type] matching [where].
Future<SocketEvent> _next(SocketClient c, String type, {bool Function(SocketEvent)? where}) =>
    c.events
        .firstWhere((e) => e.type == type && (where?.call(e) ?? true))
        .timeout(const Duration(seconds: 5));

void main() {
  final base = Platform.environment['LIVE_SERVER'];
  if (base == null) {
    test('live server contract (set LIVE_SERVER to run)', () {}, skip: 'LIVE_SERVER not set');
    return;
  }

  test('customer and astrologer complete a consultation against the real server', () async {
    final rand = Random();
    final phone = '9${List.generate(9, (_) => rand.nextInt(10)).join()}';
    final anon = _client(base);

    // ---- config
    final config = AppConfig.fromJson(await anon.get<Map<String, dynamic>>('/config'));
    expect(config.isDemoLogin, isTrue, reason: 'run against a demo-login server');
    expect(config.expertise, isNotEmpty);

    // ---- customer signs up with OTP
    final otp = await anon.post<Map<String, dynamic>>(
        '/auth/send-otp', {'phone': phone, 'purpose': 'signup'});
    final signup = await anon.post<Map<String, dynamic>>(
        '/auth/verify-otp', {'phone': phone, 'otp': otp['devOtp'], 'name': 'Contract Tester'});
    final customerToken = signup['token'] as String;
    var customer = User.fromJson(signup['user'] as Map<String, dynamic>);
    expect(customer.isAstrologer, isFalse);
    expect(customer.profileComplete, isFalse);

    final api = _client(base, customerToken);
    customer = User.fromJson(await api.put<Map<String, dynamic>>('/me', {
      'name': 'Contract Tester',
      'dob': '1995-08-15',
      'birthTime': '06:30',
      'birthPlace': 'Pune, Maharashtra',
      'gender': 'Male',
    }));
    expect(customer.profileComplete, isTrue);
    expect(customer.sunSign, 'Leo');

    // ---- wallet: welcome bonus
    var wallet = Wallet.fromJson(await api.get<Map<String, dynamic>>('/wallet'));
    expect(wallet.balance, 100);
    expect(wallet.transactions.single.type, TxnType.bonus);

    // ---- astrologers list + detail
    final list = (await api.get<List<dynamic>>('/astrologers', query: {'sort': 'recommended'}))
        .map((e) => Astrologer.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(list.length, 12);
    final detail = Astrologer.fromJson(await api.get<Map<String, dynamic>>('/astrologers/a2'));
    expect(detail.name, 'Tara Mehta');
    expect(detail.pricing['chat'], 20);

    // ---- astrologer signs in to the astrologer app
    final aotp = await anon.post<Map<String, dynamic>>(
        '/auth/send-otp', {'phone': '9100000002', 'purpose': 'astrologer'});
    final alogin = await anon.post<Map<String, dynamic>>(
        '/auth/verify-otp', {'phone': '9100000002', 'otp': aotp['devOtp']});
    final astroToken = alogin['token'] as String;
    final astroUser = User.fromJson(alogin['user'] as Map<String, dynamic>);
    expect(astroUser.isAstrologer, isTrue);
    expect(astroUser.astrologerId, 'a2');
    final astroApi = _client(base, astroToken);
    final desk = DeskProfile.fromJson(await astroApi.get<Map<String, dynamic>>('/astrologer/me'));
    expect(desk.astrologer.name, 'Tara Mehta');
    expect(desk.stats.totalConsultations, 0);

    // ---- roles stay apart, with readable errors
    try {
      await astroApi.get<List<dynamic>>('/sessions');
      fail('astrologer token must not work on customer endpoints');
    } on AppException catch (e) {
      expect(e.code, 'wrong_role');
      expect(e.statusCode, 403);
    }

    // ---- both sides connect in real time
    final customerSocket = SocketClient()..connect(_ws(base, customerToken));
    final astroSocket = SocketClient()..connect(_ws(base, astroToken));
    addTearDown(() {
      customerSocket.dispose();
      astroSocket.dispose();
    });
    await Future.wait([
      customerSocket.events.firstWhere((e) => e.type == 'ready').timeout(const Duration(seconds: 5)),
      astroSocket.events.firstWhere((e) => e.type == 'ready').timeout(const Duration(seconds: 5)),
    ]);

    // ---- customer asks for a chat; the astrologer hears about it live
    final incoming = _next(astroSocket, 'session.updated',
        where: (e) => e.data['status'] == 'requested');
    final requested = Consultation.fromJson(
        await api.post<Map<String, dynamic>>('/sessions', {'astrologerId': 'a2', 'type': 'chat'}));
    expect(requested.status, ConsultationStatus.requested);
    final pushed = Consultation.fromJson((await incoming).data);
    expect(pushed.id, requested.id);
    expect(pushed.userName, 'Contract Tester');
    expect(pushed.userBirthPlace, 'Pune, Maharashtra');

    // ---- astrologer accepts: first minute is charged, balance pushed live
    final walletPush = _next(customerSocket, 'wallet.updated');
    final started = _next(customerSocket, 'session.updated',
        where: (e) => e.data['status'] == 'ongoing');
    final accepted = Consultation.fromJson(
        await astroApi.post<Map<String, dynamic>>('/astrologer/sessions/${requested.id}/accept'));
    expect(accepted.status, ConsultationStatus.ongoing);
    expect(accepted.chargedMinutes, 1);
    expect(accepted.paidUntil, isNotNull);
    expect(accepted.paidSecondsLeft, inInclusiveRange(1, 60));
    expect((await walletPush).data['balance'], 80);
    expect(Consultation.fromJson((await started).data).status, ConsultationStatus.ongoing);

    // ---- chat both ways
    final toCustomer = _next(customerSocket, 'chat.message',
        where: (e) => e.data['sender'] == 'astrologer');
    astroSocket.send('chat.send',
        {'sessionId': requested.id, 'text': 'Namaste. What is your question?', 'clientId': 'c1'});
    final fromAstro = ChatMessage.fromJson((await toCustomer).data);
    expect(fromAstro.sender, MessageSender.astrologer);
    expect(fromAstro.text, contains('Namaste'));
    expect(fromAstro.clientId, 'c1');

    final toAstro = _next(astroSocket, 'chat.message', where: (e) => e.data['sender'] == 'user');
    customerSocket.send('chat.send',
        {'sessionId': requested.id, 'text': 'Will I change jobs?', 'clientId': 'c2'});
    expect(ChatMessage.fromJson((await toAstro).data).text, 'Will I change jobs?');

    final history = (await api.get<List<dynamic>>('/sessions/${requested.id}/messages'))
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(history.where((m) => m.sender != MessageSender.system).length, 2);
    expect(history.any((m) => m.sender == MessageSender.system), isTrue, reason: '"joined" notice');

    // ---- astrologer ends; both sides agree on the outcome and the money
    final ended = Consultation.fromJson(
        await astroApi.post<Map<String, dynamic>>('/astrologer/sessions/${requested.id}/end'));
    expect(ended.status, ConsultationStatus.completed);
    expect(ended.endReason, 'astrologer_ended');
    expect(ended.cost, 20);
    expect(ended.earning, 14);

    final customerView = Consultation.fromJson(
        await api.get<Map<String, dynamic>>('/sessions/${requested.id}'));
    expect(customerView.status, ConsultationStatus.completed);
    expect(customerView.endReasonText, 'Tara Mehta ended the consultation');

    wallet = Wallet.fromJson(await api.get<Map<String, dynamic>>('/wallet'));
    expect(wallet.balance, 80);
    final charge = wallet.transactions.firstWhere((t) => t.type == TxnType.charge);
    expect(charge.amount, -20);
    expect(charge.astrologerName, 'Tara Mehta');
    expect(charge.sessionId, requested.id);

    final earned = DeskProfile.fromJson(await astroApi.get<Map<String, dynamic>>('/astrologer/me'));
    expect(earned.stats.totalConsultations, 1);
    expect(earned.stats.totalEarnings, 14);

    // ---- rating and history
    final rated = Consultation.fromJson(await api.post<Map<String, dynamic>>(
        '/sessions/${requested.id}/review', {'rating': 5, 'comment': 'Insightful'}));
    expect(rated.rating, 5);
    final all = (await api.get<List<dynamic>>('/sessions'))
        .map((e) => Consultation.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(all.single.id, requested.id);
    final astroSessions = (await astroApi.get<List<dynamic>>('/astrologer/sessions'))
        .map((e) => Consultation.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(astroSessions.single.rating, 5);

    // ---- error shapes the UI relies on
    try {
      await api.post<Map<String, dynamic>>('/wallet/topup', {'amount': 5});
      fail('amount below the minimum must be refused');
    } on AppException catch (e) {
      expect(e.code, 'invalid_amount');
    }
    final top = Wallet.fromJson(await api.post<Map<String, dynamic>>('/wallet/topup', {'amount': 500}));
    expect(top.balance, 580);

    await api.post<Map<String, dynamic>>('/auth/logout');
    try {
      await api.get<Map<String, dynamic>>('/me');
      fail('token must be revoked after logout');
    } on AppException catch (e) {
      expect(e.isUnauthorized, isTrue);
    }
  }, timeout: const Timeout(Duration(seconds: 40)));
}

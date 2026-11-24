import 'package:astro_connect/core/network/socket_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:astro_connect/features/astrologers/data/astrologer_repository.dart';
import 'package:astro_connect/features/astrologers/domain/astrologer.dart';
import 'package:astro_connect/features/auth/domain/auth_repository.dart';
import 'package:astro_connect/features/auth/domain/user.dart';
import 'package:astro_connect/core/errors/app_exception.dart';
import 'package:astro_connect/features/consultation/data/consultation_repository.dart';
import 'package:astro_connect/features/consultation/presentation/providers/call_controller.dart';
import 'package:astro_connect/features/desk/data/desk_repository.dart';
import 'package:astro_connect/features/desk/domain/desk.dart';
import 'package:astro_connect/features/wallet/domain/wallet.dart';
import 'package:astro_connect/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:astro_connect/features/consultation/domain/chat_message.dart';
import 'package:astro_connect/features/consultation/domain/consultation.dart';

Map<String, dynamic> sessionJson({
  String id = 's1',
  String type = 'chat',
  String status = 'ongoing',
  String? endReason,
  int chargedMinutes = 1,
  Duration? paidFor,
  int earning = 0,
  String userName = 'Asha Verma',
}) =>
    {
      'earning': earning,
      'user': {
        'name': userName,
        'dob': '1995-08-15',
        'birthTime': '06:30',
        'birthPlace': 'Pune, Maharashtra',
      },
      'chargedMinutes': chargedMinutes,
      'paidUntil': paidFor == null
          ? null
          : DateTime.now().add(paidFor).toUtc().toIso8601String(),
      'id': id,
      'type': type,
      'status': status,
      'ratePerMinute': 25,
      'requestedAt': '2026-11-24T10:00:00.000Z',
      'startedAt': status == 'requested' ? '' : '2026-11-24T10:00:05.000Z',
      'endedAt': status == 'completed' ? '2026-11-24T10:05:05.000Z' : '',
      'endReason': endReason,
      'durationSeconds': status == 'completed' ? 300 : 0,
      'cost': status == 'completed' ? 125 : 0,
      'astrologer': {'id': 'a1', 'name': 'Pt. Raghav Sharma', 'avatarUrl': ''},
      'rtc': type == 'chat' ? null : {'appId': 'app', 'channel': 'astro_$id', 'token': null},
      'serverTime': DateTime.now().toUtc().toIso8601String(),
    };

Map<String, dynamic> messageJson(String id, String sender, String text, {String? clientId}) => {
      'id': id,
      'sessionId': 's1',
      'sender': sender,
      'text': text,
      'sentAt': '2026-11-24T10:01:00.000Z',
      'clientId': ?clientId,
    };

/// Socket double: records sends, lets tests push server events.
class FakeSocket extends SocketClient {
  FakeSocket({this.connected = true});

  bool connected;
  final sent = <(String, Map<String, dynamic>)>[];

  @override
  bool send(String type, Map<String, dynamic> data) {
    if (!connected) return false;
    sent.add((type, data));
    return true;
  }

  void emit(String type, Map<String, dynamic> data) => debugEmit(SocketEvent(type, data));
}

class FakeConsultationRepository implements ConsultationRepository {
  Consultation session = Consultation.fromJson(sessionJson());
  List<ChatMessage> storedMessages = [];
  final restSent = <String>[];
  bool failSend = false;

  @override
  Future<Consultation> get(String id) async => session;

  @override
  Future<List<ChatMessage>> messages(String id) async => storedMessages;

  @override
  Future<ChatMessage> sendMessage(String id, String text, String clientId) async {
    if (failSend) throw const AppException('offline', code: 'network');
    restSent.add(text);
    return ChatMessage.fromJson(messageJson('m${restSent.length}', 'user', text, clientId: clientId));
  }

  @override
  Future<Consultation> end(String id, {String reason = 'user_ended'}) async =>
      session = Consultation.fromJson(sessionJson(status: 'completed', endReason: reason));

  @override
  Future<Consultation> cancel(String id) async =>
      session = Consultation.fromJson(sessionJson(status: 'cancelled', endReason: 'user_cancelled'));

  @override
  String get base => '/sessions';

  @override
  Future<Consultation> accept(String id) async =>
      session = Consultation.fromJson(sessionJson(id: id, status: 'ongoing'));

  @override
  Future<Consultation> reject(String id) async =>
      session = Consultation.fromJson(sessionJson(id: id, status: 'rejected', endReason: 'astrologer_declined'));

  @override
  Future<Consultation> review(String id, int rating, String comment) async => session;

  /// When set, returned by [history] instead of just [session].
  List<Consultation>? historyList;

  @override
  Future<List<Consultation>> history() async => historyList ?? [session];

  @override
  Future<Consultation> start(String astrologerId, ConsultationType type) async => session;
}

class FakeAuthRepository implements AuthRepository {
  String? lastPurpose;
  AppException? sendError;
  final validOtp = '482913';
  User? user;

  @override
  User? cachedUser() => user;

  @override
  Future<User> fetchMe() async => user!;

  @override
  Future<OtpTicket> sendOtp(String phone, OtpPurpose purpose) async {
    lastPurpose = purpose.name;
    if (sendError != null) throw sendError!;
    return OtpTicket(resendIn: const Duration(seconds: 30), devOtp: validOtp);
  }

  @override
  Future<User> verifyOtp({
    required String phone,
    required String otp,
    required OtpPurpose purpose,
    String? name,
  }) async {
    if (otp != validOtp) {
      throw const AppException('Incorrect OTP. 4 attempts left.', code: 'otp_invalid');
    }
    return user = purpose == OtpPurpose.astrologer
        ? User(id: 'a1', phone: phone, name: 'Pt. Raghav Sharma', role: 'astrologer', astrologerId: 'a1')
        : User(id: 'u1', phone: phone, name: name ?? '');
  }

  @override
  Future<User> updateProfile(ProfileInput input) async => user = User(
        id: 'u1',
        phone: user?.phone ?? '9876543210',
        name: input.name,
        dob: input.dob,
        birthTime: input.birthTime,
        birthPlace: input.birthPlace,
      );

  @override
  Future<void> logout() async => user = null;
}

const sampleAstrologerJson = {
  'id': 'a1',
  'name': 'Pt. Raghav Sharma',
  'avatarUrl': '',
  'expertise': ['Vedic', 'KP'],
  'languages': ['Hindi', 'English'],
  'experienceYears': 15,
  'rating': 4.8,
  'ratingCount': 2140,
  'pricing': {'chat': 25, 'voice': 30, 'video': 40},
  'status': 'online',
  'totalConsultations': 100,
};

Astrologer sampleAstrologer() => Astrologer.fromJson(sampleAstrologerJson);

// ---------------------------------------------------------------- astrologers

Astrologer _astro(
  String id,
  String name,
  List<String> expertise,
  List<String> languages,
  int years,
  double rating,
  int count,
  int chat,
  String status, {
  List<Map<String, dynamic>> reviews = const [],
  String bio = 'Third-generation Vedic astrologer from Varanasi, specialising in career timing using dasha analysis and KP sub-lords.',
}) =>
    Astrologer.fromJson({
      'id': id,
      'name': name,
      'avatarUrl': '',
      'expertise': expertise,
      'languages': languages,
      'experienceYears': years,
      'rating': rating,
      'ratingCount': count,
      'pricing': {'chat': chat, 'voice': chat + 5, 'video': chat + 15},
      'status': status,
      'totalConsultations': count * 7,
      'bio': bio,
      'reviews': reviews,
    });

List<Astrologer> sampleAstrologers() => [
      _astro('a1', 'Pt. Raghav Sharma', ['Vedic', 'KP', 'Career'], ['Hindi', 'English'], 15, 4.8, 2140, 25, 'online', reviews: [
        {'userName': 'Ankita', 'rating': 5, 'comment': 'Very accurate about my job change. Calm and patient.', 'createdAt': '2026-11-20T10:00:00Z'},
        {'userName': 'Rohit', 'rating': 4, 'comment': 'Explained my dasha period clearly.', 'createdAt': '2026-11-10T10:00:00Z'},
      ]),
      _astro('a2', 'Tara Mehta', ['Tarot', 'Love & Relationship'], ['English', 'Hindi', 'Gujarati'], 8, 4.7, 1320, 20, 'online'),
      _astro('a3', 'Acharya Vikram Joshi', ['Vedic', 'Vastu', 'Palmistry'], ['Hindi', 'Marathi'], 22, 4.9, 3890, 40, 'busy'),
      _astro('a4', 'Neha Kapoor', ['Numerology', 'Career'], ['English', 'Hindi', 'Punjabi'], 6, 4.5, 640, 15, 'online'),
      _astro('a5', 'Swami Anand Giri', ['Vedic', 'Face Reading'], ['Hindi', 'Sanskrit'], 30, 4.6, 5100, 35, 'offline'),
      _astro('a6', 'Priya Iyer', ['Tarot', 'Numerology'], ['English', 'Tamil'], 5, 4.4, 410, 12, 'online'),
    ];

class FakeAstrologerRepository implements AstrologerRepository {
  FakeAstrologerRepository({this.callsEnabled = true});

  final bool callsEnabled;
  final all = sampleAstrologers();

  @override
  Future<List<Astrologer>> list(AstrologerFilter filter) async => all;

  @override
  Future<Astrologer> get(String id) async => all.firstWhere((a) => a.id == id);

  @override
  Future<AppConfig> config() async => AppConfig(callsEnabled: callsEnabled, expertise: const [
        'Vedic', 'Tarot', 'Numerology', 'Vastu', 'Palmistry', 'KP', 'Love & Relationship', 'Career', 'Face Reading',
      ]);
}


// --------------------------------------------------------------------- wallet

/// Wallet with a fixed balance and no network, for widget tests.
class FakeWalletNotifier extends WalletNotifier {
  FakeWalletNotifier({this.balance = 250, this.transactions = const []});

  final int balance;
  final List<WalletTxn> transactions;
  final topUps = <int>[];

  @override
  Future<Wallet> build() async => Wallet(balance: balance, transactions: transactions);

  @override
  Future<void> refresh() async {}

  @override
  Future<void> topUp(int amount) async {
    topUps.add(amount);
    state = AsyncData(state.requireValue.copyWith(balance: state.requireValue.balance + amount));
  }
}


// ----------------------------------------------------------------------- desk

class FakeDeskRepository implements DeskRepository {
  FakeDeskRepository({this.online = true, this.stats = const DeskStats(
    totalConsultations: 12,
    totalEarnings: 1540,
    todayConsultations: 3,
    todayEarnings: 420,
  )});

  bool online;
  DeskStats stats;
  AppException? setOnlineError;
  final onlineCalls = <bool>[];

  @override
  Future<DeskProfile> me() async => DeskProfile(
        astrologer: sampleAstrologers().first.withStatus(
            online ? AstrologerStatus.online : AstrologerStatus.offline),
        stats: stats,
      );

  @override
  Future<void> setOnline(bool value) async {
    if (setOnlineError != null) throw setOnlineError!;
    onlineCalls.add(value);
    online = value;
  }
}

// ----------------------------------------------------------------------- call

/// Call controller frozen in a given state: no Agora, no permissions.
class FakeCallController extends CallController {
  FakeCallController(super.sessionId, this.initial);

  final CallState initial;
  int joins = 0;

  @override
  CallState build() => initial;

  @override
  Future<void> join(RtcInfo rtc, {required bool video}) async => joins++;
}

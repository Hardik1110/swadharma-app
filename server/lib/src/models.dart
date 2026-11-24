/// Plain data models shared by the store, services and API.
library;

String _iso(DateTime? d) => d?.toUtc().toIso8601String() ?? '';
DateTime? _parse(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.parse(v) : null;

class User {
  User({
    required this.id,
    required this.phone,
    this.name = '',
    this.gender = '',
    this.dob = '',
    this.birthTime = '',
    this.birthPlace = '',
    this.balance = 0,
    this.walletInitialized = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String phone;

  /// Wallet balance in whole rupees.
  int balance;

  /// Set once the welcome bonus has been credited.
  bool walletInitialized;
  String name;
  String gender;

  /// yyyy-MM-dd
  String dob;

  /// HH:mm (24h)
  String birthTime;
  String birthPlace;
  final DateTime createdAt;

  bool get profileComplete =>
      name.isNotEmpty &&
      dob.isNotEmpty &&
      birthTime.isNotEmpty &&
      birthPlace.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'gender': gender,
        'dob': dob,
        'birthTime': birthTime,
        'birthPlace': birthPlace,
        'profileComplete': profileComplete,
        'balance': balance,
        'walletInitialized': walletInitialized,
        'createdAt': _iso(createdAt),
      };

  factory User.fromJson(Map<String, dynamic> j) => User(
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        walletInitialized: j['walletInitialized'] as bool? ?? false,
        id: j['id'] as String,
        phone: j['phone'] as String,
        name: j['name'] as String? ?? '',
        gender: j['gender'] as String? ?? '',
        dob: j['dob'] as String? ?? '',
        birthTime: j['birthTime'] as String? ?? '',
        birthPlace: j['birthPlace'] as String? ?? '',
        createdAt: _parse(j['createdAt']),
      );
}

enum AstrologerStatus { online, busy, offline }

class Review {
  Review({
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String userName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'rating': rating,
        'comment': comment,
        'createdAt': _iso(createdAt),
      };

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        userName: j['userName'] as String,
        rating: j['rating'] as int,
        comment: j['comment'] as String? ?? '',
        createdAt: _parse(j['createdAt']) ?? DateTime.now(),
      );
}

class Astrologer {
  Astrologer({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.expertise,
    required this.languages,
    required this.experienceYears,
    required this.rating,
    required this.ratingCount,
    required this.pricing,
    required this.status,
    required this.bio,
    required this.totalConsultations,
    this.phone = '',
    List<Review>? reviews,
  }) : reviews = reviews ?? [];

  final String id;

  /// Login number for the astrologer app. Never sent to consumers.
  String phone;
  final String name;
  final String avatarUrl;
  final List<String> expertise;
  final List<String> languages;
  final int experienceYears;
  double rating;
  int ratingCount;

  /// INR per minute, keyed by consultation type (chat / voice / video).
  final Map<String, int> pricing;
  AstrologerStatus status;
  final String bio;
  int totalConsultations;
  final List<Review> reviews;

  void addReview(Review r) {
    rating = ((rating * ratingCount) + r.rating) / (ratingCount + 1);
    ratingCount++;
    reviews.insert(0, r);
  }

  Map<String, dynamic> toSummaryJson() => {
        'id': id,
        'name': name,
        'avatarUrl': avatarUrl,
        'expertise': expertise,
        'languages': languages,
        'experienceYears': experienceYears,
        'rating': double.parse(rating.toStringAsFixed(1)),
        'ratingCount': ratingCount,
        'pricing': pricing,
        'status': status.name,
        'totalConsultations': totalConsultations,
      };

  Map<String, dynamic> toJson() => {
        ...toSummaryJson(),
        'bio': bio,
        'reviews': reviews.take(20).map((r) => r.toJson()).toList(),
      };

  /// Everything, including private fields. Used only for persistence.
  Map<String, dynamic> toStoreJson() => {
        ...toJson(),
        'phone': phone,
        'reviews': reviews.map((r) => r.toJson()).toList(),
      };

  factory Astrologer.fromJson(Map<String, dynamic> j) => Astrologer(
        phone: j['phone'] as String? ?? '',
        id: j['id'] as String,
        name: j['name'] as String,
        avatarUrl: j['avatarUrl'] as String,
        expertise: (j['expertise'] as List).cast<String>(),
        languages: (j['languages'] as List).cast<String>(),
        experienceYears: j['experienceYears'] as int,
        rating: (j['rating'] as num).toDouble(),
        ratingCount: j['ratingCount'] as int,
        pricing: (j['pricing'] as Map).cast<String, int>(),
        status: AstrologerStatus.values.byName(j['status'] as String),
        bio: j['bio'] as String,
        totalConsultations: j['totalConsultations'] as int,
        reviews: ((j['reviews'] as List?) ?? [])
            .map((r) => Review.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}

enum SessionType { chat, voice, video }

/// requested -> ongoing -> completed, or requested -> rejected/cancelled/missed.
enum SessionStatus { requested, ongoing, completed, rejected, cancelled, missed }

class Session {
  Session({
    required this.id,
    required this.userId,
    required this.astrologerId,
    required this.type,
    required this.ratePerMinute,
    this.status = SessionStatus.requested,
    DateTime? requestedAt,
    this.startedAt,
    this.endedAt,
    this.endReason,
    this.rating,
    this.chargedMinutes = 0,
  }) : requestedAt = requestedAt ?? DateTime.now();

  final String id;
  final String userId;
  final String astrologerId;
  final SessionType type;
  final int ratePerMinute;
  SessionStatus status;
  final DateTime requestedAt;
  DateTime? startedAt;
  DateTime? endedAt;

  /// Why the session finished: user_ended, astrologer_ended, user_disconnected,
  /// astrologer_disconnected, astrologer_busy, timeout, server_restart ...
  String? endReason;
  int? rating;

  /// Minutes already deducted from the wallet. The first is taken when the
  /// astrologer accepts, then one at the start of each further minute.
  int chargedMinutes;

  bool get isActive =>
      status == SessionStatus.requested || status == SessionStatus.ongoing;

  bool get isCall => type != SessionType.chat;

  String get channelName => 'astro_$id';

  int get durationSeconds {
    if (startedAt == null) return 0;
    return (endedAt ?? DateTime.now()).difference(startedAt!).inSeconds;
  }

  int get cost => chargedMinutes * ratePerMinute;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'astrologerId': astrologerId,
        'type': type.name,
        'status': status.name,
        'ratePerMinute': ratePerMinute,
        'requestedAt': _iso(requestedAt),
        'startedAt': _iso(startedAt),
        'endedAt': _iso(endedAt),
        'endReason': endReason,
        'rating': rating,
        'chargedMinutes': chargedMinutes,
      };

  factory Session.fromJson(Map<String, dynamic> j) {
    final started = _parse(j['startedAt']);
    final ended = _parse(j['endedAt']);
    // Sessions saved before wallets existed: bill started minutes, min one.
    final legacy = started == null
        ? 0
        : ((((ended ?? DateTime.now()).difference(started).inSeconds) + 59) ~/ 60)
            .clamp(1, 1 << 30);
    return Session._restore(j, legacy);
  }

  factory Session._restore(Map<String, dynamic> j, int legacyMinutes) => Session(
        chargedMinutes: (j['chargedMinutes'] as num?)?.toInt() ?? legacyMinutes,
        id: j['id'] as String,
        userId: j['userId'] as String,
        astrologerId: j['astrologerId'] as String,
        type: SessionType.values.byName(j['type'] as String),
        ratePerMinute: j['ratePerMinute'] as int,
        status: SessionStatus.values.byName(j['status'] as String),
        requestedAt: _parse(j['requestedAt']),
        startedAt: _parse(j['startedAt']),
        endedAt: _parse(j['endedAt']),
        endReason: j['endReason'] as String?,
        rating: j['rating'] as int?,
      );
}

enum Sender { user, astrologer, system }

class Message {
  Message({
    required this.id,
    required this.sessionId,
    required this.sender,
    required this.text,
    DateTime? sentAt,
    this.clientId,
  }) : sentAt = sentAt ?? DateTime.now();

  final String id;
  final String sessionId;
  final Sender sender;
  final String text;
  final DateTime sentAt;

  /// Echoed back so the sender can reconcile its optimistic copy.
  final String? clientId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'sender': sender.name,
        'text': text,
        'sentAt': _iso(sentAt),
        if (clientId != null) 'clientId': clientId,
      };

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        sessionId: j['sessionId'] as String,
        sender: Sender.values.byName(j['sender'] as String),
        text: j['text'] as String,
        sentAt: _parse(j['sentAt']),
        clientId: j['clientId'] as String?,
      );
}

class ApiError implements Exception {
  ApiError(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  @override
  String toString() => 'ApiError($status, $code, $message)';
}

enum TxnType { topup, bonus, charge }

/// One wallet ledger entry. [amount] is signed: credits positive, debits negative.
class WalletTxn {
  WalletTxn({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.note,
    this.sessionId,
    this.astrologerName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String userId;
  final TxnType type;
  final int amount;
  final int balanceAfter;
  final String note;
  final String? sessionId;
  final String? astrologerName;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'type': type.name,
        'amount': amount,
        'balanceAfter': balanceAfter,
        'note': note,
        'sessionId': sessionId,
        'astrologerName': astrologerName,
        'createdAt': _iso(createdAt),
      };

  factory WalletTxn.fromJson(Map<String, dynamic> j) => WalletTxn(
        id: j['id'] as String,
        userId: j['userId'] as String,
        type: TxnType.values.byName(j['type'] as String),
        amount: (j['amount'] as num).toInt(),
        balanceAfter: (j['balanceAfter'] as num).toInt(),
        note: j['note'] as String? ?? '',
        sessionId: j['sessionId'] as String?,
        astrologerName: j['astrologerName'] as String?,
        createdAt: _parse(j['createdAt']),
      );
}

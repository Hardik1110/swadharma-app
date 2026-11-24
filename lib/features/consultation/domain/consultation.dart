import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum ConsultationType {
  chat('Chat', Icons.chat_bubble_rounded),
  voice('Voice call', Icons.call_rounded),
  video('Video call', Icons.videocam_rounded);

  const ConsultationType(this.label, this.icon);
  final String label;
  final IconData icon;

  bool get isCall => this != chat;
}

enum ConsultationStatus {
  requested('Waiting'),
  ongoing('Ongoing'),
  completed('Completed'),
  rejected('Declined'),
  cancelled('Cancelled'),
  missed('Missed');

  const ConsultationStatus(this.label);
  final String label;

  bool get isActive => this == requested || this == ongoing;
}

class RtcInfo extends Equatable {
  const RtcInfo({required this.appId, required this.channel, this.token});

  final String appId;
  final String channel;
  final String? token;

  factory RtcInfo.fromJson(Map<String, dynamic> j) => RtcInfo(
        appId: j['appId'] as String,
        channel: j['channel'] as String,
        token: j['token'] as String?,
      );

  @override
  List<Object?> get props => [appId, channel, token];
}

DateTime? _date(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.parse(v) : null;

class Consultation extends Equatable {
  const Consultation({
    required this.id,
    required this.type,
    required this.status,
    required this.astrologerId,
    required this.astrologerName,
    required this.astrologerAvatar,
    required this.ratePerMinute,
    required this.requestedAt,
    this.startedAt,
    this.endedAt,
    this.endReason,
    this.durationSeconds = 0,
    this.cost = 0,
    this.rating,
    this.rtc,
    this.lastMessageText,
    this.clockOffset = Duration.zero,
    this.chargedMinutes = 0,
    this.paidUntil,
    this.earning = 0,
    this.userName = '',
    this.userDob = '',
    this.userBirthTime = '',
    this.userBirthPlace = '',
  });

  final String id;
  final ConsultationType type;
  final ConsultationStatus status;
  final String astrologerId;
  final String astrologerName;
  final String astrologerAvatar;
  final int ratePerMinute;
  final DateTime requestedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? endReason;
  final int durationSeconds;
  final int cost;
  final int? rating;
  final RtcInfo? rtc;
  final String? lastMessageText;

  /// Minutes already deducted from the wallet.
  final int chargedMinutes;

  /// The moment the minutes paid so far run out.
  final DateTime? paidUntil;

  /// What the astrologer earns from this session (their view).
  final int earning;

  /// The consumer's details, shared with the astrologer for the reading.
  final String userName;
  final String userDob;
  final String userBirthTime;
  final String userBirthPlace;

  /// serverTime - deviceTime, so timers stay correct on skewed clocks.
  final Duration clockOffset;

  DateTime get serverNow => DateTime.now().add(clockOffset);

  /// Live duration for ongoing sessions, final duration otherwise.
  int get elapsedSeconds {
    if (startedAt == null) return 0;
    if (status != ConsultationStatus.ongoing) return durationSeconds;
    return serverNow.difference(startedAt!).inSeconds.clamp(0, 1 << 31);
  }

  /// Seconds of paid time left in an ongoing session (0 when none).
  int get paidSecondsLeft {
    final until = paidUntil;
    if (until == null || status != ConsultationStatus.ongoing) return 0;
    return until.difference(serverNow).inSeconds.clamp(0, 1 << 31);
  }

  int get waitingSeconds =>
      serverNow.difference(requestedAt).inSeconds.clamp(0, 1 << 31);

  /// The person on the other side, from the viewer's point of view.
  String peerName({required bool asAstrologer}) => asAstrologer ? userName : astrologerName;

  String peerAvatar({required bool asAstrologer}) => asAstrologer ? '' : astrologerAvatar;

  /// Why the session ended, worded for the astrologer.
  String get endReasonTextForAstrologer {
    final who = userName.isEmpty ? 'The customer' : userName;
    return switch (endReason) {
      'user_ended' => '$who ended the consultation',
      'astrologer_ended' => 'You ended the consultation',
      'user_disconnected' => '$who got disconnected',
      'astrologer_disconnected' => 'You got disconnected',
      'insufficient_balance' => "$who's wallet balance ran out",
      'user_cancelled' => '$who cancelled the request',
      'timeout' => 'The request timed out before you responded',
      'astrologer_declined' => 'You declined this request',
      'call_failed' => 'The call could not be connected',
      'server_restart' => 'Interrupted by a server restart',
      _ => '',
    };
  }

  /// Human explanation of why the session ended.
  String get endReasonText => switch (endReason) {
        'user_ended' => 'You ended the consultation',
        'astrologer_ended' => '$astrologerName ended the consultation',
        'user_disconnected' => 'Ended because your connection was lost',
        'astrologer_disconnected' => '$astrologerName got disconnected',
        'call_failed' => 'The call could not be connected',
        'astrologer_busy' => '$astrologerName is with another client',
        'astrologer_declined' => '$astrologerName couldn\'t take your request',
        'timeout' => '$astrologerName didn\'t respond in time',
        'user_cancelled' => 'You cancelled the request',
        'server_restart' => 'Interrupted by a server restart',
        'insufficient_balance' => status == ConsultationStatus.rejected
            ? 'Your wallet balance was too low to start'
            : 'Ended because your wallet balance ran out',
        _ => '',
      };

  factory Consultation.fromJson(Map<String, dynamic> j) {
    final astro = j['astrologer'] as Map<String, dynamic>;
    final serverTime = _date(j['serverTime']);
    final last = j['lastMessage'] as Map<String, dynamic>?;
    final user = j['user'] as Map<String, dynamic>?;
    return Consultation(
      chargedMinutes: (j['chargedMinutes'] as num?)?.toInt() ?? 0,
      paidUntil: _date(j['paidUntil']),
      earning: (j['earning'] as num?)?.toInt() ?? 0,
      userName: user?['name'] as String? ?? '',
      userDob: user?['dob'] as String? ?? '',
      userBirthTime: user?['birthTime'] as String? ?? '',
      userBirthPlace: user?['birthPlace'] as String? ?? '',
      id: j['id'] as String,
      type: ConsultationType.values.byName(j['type'] as String),
      status: ConsultationStatus.values.byName(j['status'] as String),
      astrologerId: astro['id'] as String,
      astrologerName: astro['name'] as String,
      astrologerAvatar: astro['avatarUrl'] as String? ?? '',
      ratePerMinute: (j['ratePerMinute'] as num).toInt(),
      requestedAt: _date(j['requestedAt'])!,
      startedAt: _date(j['startedAt']),
      endedAt: _date(j['endedAt']),
      endReason: j['endReason'] as String?,
      durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
      cost: (j['cost'] as num?)?.toInt() ?? 0,
      rating: (j['rating'] as num?)?.toInt(),
      rtc: j['rtc'] == null ? null : RtcInfo.fromJson(j['rtc'] as Map<String, dynamic>),
      lastMessageText: last?['text'] as String?,
      clockOffset: serverTime == null
          ? Duration.zero
          : serverTime.difference(DateTime.now()),
    );
  }

  @override
  List<Object?> get props =>
      [id, status, startedAt, endedAt, endReason, rating, cost, rtc, lastMessageText, chargedMinutes, paidUntil];
}

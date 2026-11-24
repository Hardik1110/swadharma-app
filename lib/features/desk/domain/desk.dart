import 'package:equatable/equatable.dart';

import '../../astrologers/domain/astrologer.dart';

/// Totals shown on the astrologer's dashboard.
class DeskStats extends Equatable {
  const DeskStats({
    this.totalConsultations = 0,
    this.totalEarnings = 0,
    this.todayConsultations = 0,
    this.todayEarnings = 0,
    this.pendingRequests = 0,
    this.share = .7,
  });

  final int totalConsultations;
  final int totalEarnings;
  final int todayConsultations;
  final int todayEarnings;
  final int pendingRequests;

  /// Fraction of each charge the astrologer keeps.
  final double share;

  factory DeskStats.fromJson(Map<String, dynamic> j) => DeskStats(
        totalConsultations: (j['totalConsultations'] as num?)?.toInt() ?? 0,
        totalEarnings: (j['totalEarnings'] as num?)?.toInt() ?? 0,
        todayConsultations: (j['todayConsultations'] as num?)?.toInt() ?? 0,
        todayEarnings: (j['todayEarnings'] as num?)?.toInt() ?? 0,
        pendingRequests: (j['pendingRequests'] as num?)?.toInt() ?? 0,
        share: (j['share'] as num?)?.toDouble() ?? .7,
      );

  @override
  List<Object?> get props =>
      [totalConsultations, totalEarnings, todayConsultations, todayEarnings, pendingRequests];
}

/// The signed-in astrologer's own profile plus their numbers.
class DeskProfile extends Equatable {
  const DeskProfile({required this.astrologer, required this.stats});

  final Astrologer astrologer;
  final DeskStats stats;

  bool get isAvailable => astrologer.status != AstrologerStatus.offline;

  factory DeskProfile.fromJson(Map<String, dynamic> j) => DeskProfile(
        astrologer: Astrologer.fromJson(j['profile'] as Map<String, dynamic>),
        stats: DeskStats.fromJson(j['stats'] as Map<String, dynamic>),
      );

  @override
  List<Object?> get props => [astrologer, stats];
}

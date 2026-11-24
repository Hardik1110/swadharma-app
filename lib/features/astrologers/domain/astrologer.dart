import 'package:equatable/equatable.dart';

enum AstrologerStatus {
  online,
  busy,
  offline;

  static AstrologerStatus parse(String? v) =>
      values.firstWhere((s) => s.name == v, orElse: () => offline);

  String get label => switch (this) {
        online => 'Online',
        busy => 'Busy',
        offline => 'Offline',
      };
}

class Review extends Equatable {
  const Review({
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String userName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        userName: j['userName'] as String,
        rating: (j['rating'] as num).toInt(),
        comment: j['comment'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  @override
  List<Object?> get props => [userName, rating, comment, createdAt];
}

class Astrologer extends Equatable {
  const Astrologer({
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
    required this.totalConsultations,
    this.bio = '',
    this.reviews = const [],
  });

  final String id;
  final String name;
  final String avatarUrl;
  final List<String> expertise;
  final List<String> languages;
  final int experienceYears;
  final double rating;
  final int ratingCount;

  /// INR per minute keyed by `chat`, `voice`, `video`.
  final Map<String, int> pricing;
  final AstrologerStatus status;
  final int totalConsultations;
  final String bio;
  final List<Review> reviews;

  int get chatPrice => pricing['chat'] ?? 0;

  Astrologer withStatus(AstrologerStatus s) => s == status
      ? this
      : Astrologer(
          id: id,
          name: name,
          avatarUrl: avatarUrl,
          expertise: expertise,
          languages: languages,
          experienceYears: experienceYears,
          rating: rating,
          ratingCount: ratingCount,
          pricing: pricing,
          status: s,
          totalConsultations: totalConsultations,
          bio: bio,
          reviews: reviews,
        );

  factory Astrologer.fromJson(Map<String, dynamic> j) => Astrologer(
        id: j['id'] as String,
        name: j['name'] as String,
        avatarUrl: j['avatarUrl'] as String? ?? '',
        expertise: (j['expertise'] as List).cast<String>(),
        languages: (j['languages'] as List).cast<String>(),
        experienceYears: (j['experienceYears'] as num).toInt(),
        rating: (j['rating'] as num).toDouble(),
        ratingCount: (j['ratingCount'] as num).toInt(),
        pricing: (j['pricing'] as Map)
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        status: AstrologerStatus.parse(j['status'] as String?),
        totalConsultations: (j['totalConsultations'] as num?)?.toInt() ?? 0,
        bio: j['bio'] as String? ?? '',
        reviews: ((j['reviews'] as List?) ?? const [])
            .map((r) => Review.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [id, name, status, rating, ratingCount, reviews.length];
}

enum AstrologerSort {
  recommended('Recommended'),
  rating('Highest rated'),
  experience('Most experienced'),
  priceLow('Price: low to high'),
  priceHigh('Price: high to low');

  const AstrologerSort(this.label);
  final String label;

  String get apiValue => switch (this) {
        priceLow => 'price_low',
        priceHigh => 'price_high',
        _ => name,
      };
}

class AstrologerFilter extends Equatable {
  const AstrologerFilter({
    this.query = '',
    this.expertise,
    this.language,
    this.onlineOnly = false,
    this.sort = AstrologerSort.recommended,
  });

  final String query;
  final String? expertise;
  final String? language;
  final bool onlineOnly;
  final AstrologerSort sort;

  int get activeCount =>
      (expertise != null ? 1 : 0) +
      (language != null ? 1 : 0) +
      (onlineOnly ? 1 : 0) +
      (sort != AstrologerSort.recommended ? 1 : 0);

  Map<String, String> toQuery() => {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'expertise': ?expertise,
        'language': ?language,
        if (onlineOnly) 'onlineOnly': 'true',
        'sort': sort.apiValue,
      };

  AstrologerFilter copyWith({
    String? query,
    String? Function()? expertise,
    String? Function()? language,
    bool? onlineOnly,
    AstrologerSort? sort,
  }) =>
      AstrologerFilter(
        query: query ?? this.query,
        expertise: expertise != null ? expertise() : this.expertise,
        language: language != null ? language() : this.language,
        onlineOnly: onlineOnly ?? this.onlineOnly,
        sort: sort ?? this.sort,
      );

  @override
  List<Object?> get props => [query, expertise, language, onlineOnly, sort];
}

/// Server capabilities and catalogue data from `GET /config`.
class AppConfig {
  const AppConfig({
    required this.callsEnabled,
    required this.expertise,
    this.phoneAuth = 'demo',
    this.astrologerAuth,
  });

  final bool callsEnabled;
  final List<String> expertise;

  /// 'demo' (OTP shown on screen) or 'firebase' (real SMS).
  final String phoneAuth;

  /// How astrologers sign in (defaults to the same as customers).
  final String? astrologerAuth;

  bool get isDemoLogin => phoneAuth == 'demo';

  bool get isDemoAstrologerLogin => (astrologerAuth ?? phoneAuth) == 'demo';

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        callsEnabled: j['callsEnabled'] as bool? ?? false,
        expertise: ((j['expertise'] as List?) ?? const []).cast<String>(),
        phoneAuth: j['phoneAuth'] as String? ?? 'demo',
        astrologerAuth: j['astrologerAuth'] as String?,
      );
}

const kLanguages = [
  'Hindi', 'English', 'Gujarati', 'Marathi', 'Tamil', 'Telugu',
  'Kannada', 'Malayalam', 'Bengali', 'Punjabi', 'Urdu',
];

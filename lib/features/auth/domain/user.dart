import 'package:equatable/equatable.dart';

import '../../../core/utils/zodiac.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.phone,
    this.name = '',
    this.gender = '',
    this.dob = '',
    this.birthTime = '',
    this.birthPlace = '',
    this.role = 'user',
    this.astrologerId,
    this.avatarUrl = '',
  });

  final String id;

  /// 'user' (consumer) or 'astrologer' (the astrologer app).
  final String role;
  final String? astrologerId;
  final String avatarUrl;

  bool get isAstrologer => role == 'astrologer';
  final String phone;
  final String name;
  final String gender;

  /// yyyy-MM-dd
  final String dob;

  /// HH:mm, 24h
  final String birthTime;
  final String birthPlace;

  bool get profileComplete =>
      name.isNotEmpty &&
      dob.isNotEmpty &&
      birthTime.isNotEmpty &&
      birthPlace.isNotEmpty;

  DateTime? get dobDate => DateTime.tryParse(dob);

  String? get sunSign => dobDate == null ? null : Zodiac.sunSign(dobDate!);

  /// Name as shown in the UI: ALL-CAPS input is shown as "Title Case".
  String get displayName {
    final t = name.trim();
    if (t.isEmpty || t != t.toUpperCase()) return t;
    return t
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
        .join(' ');
  }

  String get firstName => displayName.split(' ').first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        phone: j['phone'] as String,
        name: j['name'] as String? ?? '',
        gender: j['gender'] as String? ?? '',
        dob: j['dob'] as String? ?? '',
        birthTime: j['birthTime'] as String? ?? '',
        birthPlace: j['birthPlace'] as String? ?? '',
        role: j['role'] as String? ?? 'user',
        astrologerId: j['astrologerId'] as String?,
        avatarUrl: j['avatarUrl'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'astrologerId': astrologerId,
        'avatarUrl': avatarUrl,
        'id': id,
        'phone': phone,
        'name': name,
        'gender': gender,
        'dob': dob,
        'birthTime': birthTime,
        'birthPlace': birthPlace,
      };

  @override
  List<Object?> get props =>
      [id, phone, name, gender, dob, birthTime, birthPlace, role, astrologerId, avatarUrl];
}

/// Editable profile fields.
class ProfileInput {
  const ProfileInput({
    required this.name,
    required this.dob,
    required this.birthTime,
    required this.birthPlace,
    this.gender = '',
  });

  final String name;
  final String dob;
  final String birthTime;
  final String birthPlace;
  final String gender;

  Map<String, dynamic> toJson() => {
        'name': name,
        'dob': dob,
        'birthTime': birthTime,
        'birthPlace': birthPlace,
        'gender': gender,
      };
}

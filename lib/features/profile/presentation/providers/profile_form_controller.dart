import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../auth/data/auth_repository_impl.dart';
import '../../../auth/domain/user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class ProfileFormState extends Equatable {
  const ProfileFormState({
    this.name = '',
    this.gender = '',
    this.dob,
    this.birthTime,
    this.birthPlace = '',
    this.saving = false,
    this.error,
    this.showErrors = false,
  });

  factory ProfileFormState.fromUser(User? u) {
    TimeOfDay? time;
    final parts = (u?.birthTime ?? '').split(':');
    if (parts.length == 2) {
      time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    return ProfileFormState(
      name: u?.name ?? '',
      gender: u?.gender ?? '',
      dob: u?.dobDate,
      birthTime: time,
      birthPlace: u?.birthPlace ?? '',
    );
  }

  final String name;
  final String gender;
  final DateTime? dob;
  final TimeOfDay? birthTime;
  final String birthPlace;
  final bool saving;
  final AppException? error;

  /// Field errors are shown only after the first submit attempt.
  final bool showErrors;

  String? get nameError =>
      name.trim().length < 2 ? 'Please enter your full name' : null;
  String? get dobError => dob == null ? 'Select your date of birth' : null;
  String? get timeError => birthTime == null ? 'Select your birth time' : null;
  String? get placeError =>
      birthPlace.trim().length < 2 ? 'Enter the city you were born in' : null;
  bool get isValid =>
      nameError == null && dobError == null && timeError == null && placeError == null;

  ProfileFormState copyWith({
    String? name,
    String? gender,
    DateTime? dob,
    TimeOfDay? birthTime,
    String? birthPlace,
    bool? saving,
    AppException? error,
    bool? showErrors,
  }) =>
      ProfileFormState(
        name: name ?? this.name,
        gender: gender ?? this.gender,
        dob: dob ?? this.dob,
        birthTime: birthTime ?? this.birthTime,
        birthPlace: birthPlace ?? this.birthPlace,
        saving: saving ?? this.saving,
        error: error,
        showErrors: showErrors ?? this.showErrors,
      );

  @override
  List<Object?> get props =>
      [name, gender, dob, birthTime, birthPlace, saving, error, showErrors];
}

final profileFormProvider =
    NotifierProvider.autoDispose<ProfileFormController, ProfileFormState>(
        ProfileFormController.new);

class ProfileFormController extends Notifier<ProfileFormState> {
  @override
  ProfileFormState build() => ProfileFormState.fromUser(ref.read(authProvider).value);

  void setName(String v) => state = state.copyWith(name: v);
  void setGender(String v) => state = state.copyWith(gender: v);
  void setDob(DateTime v) => state = state.copyWith(dob: v);
  void setBirthTime(TimeOfDay v) => state = state.copyWith(birthTime: v);
  void setBirthPlace(String v) => state = state.copyWith(birthPlace: v);

  /// Returns true when saved.
  Future<bool> save() async {
    if (!state.isValid) {
      state = state.copyWith(showErrors: true);
      return false;
    }
    state = state.copyWith(saving: true, showErrors: true);
    final t = state.birthTime!;
    try {
      final user = await ref.read(authRepositoryProvider).updateProfile(ProfileInput(
            name: state.name.trim(),
            gender: state.gender,
            dob: DateFormat('yyyy-MM-dd').format(state.dob!),
            birthTime:
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
            birthPlace: state.birthPlace.trim(),
          ));
      ref.read(authProvider.notifier).setUser(user);
      if (ref.mounted) state = state.copyWith(saving: false);
      return true;
    } on AppException catch (e) {
      if (ref.mounted) state = state.copyWith(saving: false, error: e);
      return false;
    }
  }
}

import 'package:astro_connect/core/network/realtime_providers.dart';
import 'package:astro_connect/features/auth/data/auth_repository_impl.dart';
import 'package:astro_connect/features/auth/domain/user.dart';
import 'package:astro_connect/features/consultation/data/consultation_repository.dart';
import 'package:astro_connect/features/consultation/domain/consultation.dart';
import 'package:astro_connect/features/consultation/presentation/pages/history_page.dart';
import 'package:astro_connect/features/profile/presentation/pages/profile_form_page.dart';
import 'package:astro_connect/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'harness.dart';

const _complete = User(
  id: 'u1',
  phone: '9876543210',
  name: 'Hardik Dagli',
  gender: 'Male',
  dob: '1995-08-15',
  birthTime: '06:30',
  birthPlace: 'Pune, Maharashtra',
);

Consultation _c(String id, String type, String status, {String? reason, String astro = 'Pt. Raghav Sharma'}) {
  final j = sessionJson(id: id, type: type, status: status, endReason: reason);
  (j['astrologer'] as Map)['name'] = astro;
  return Consultation.fromJson(j);
}

void main() {
  testWidgets('profile', (t) => snapshot(t, 'profile', const ProfilePage(),
      size: const Size(390, 900),
      overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository()..user = _complete)]));

  testWidgets('profile_form_edit', (t) => snapshot(t, 'profile_form_edit',
      const ProfileFormPage(isEdit: true),
      size: const Size(390, 950),
      overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository()..user = _complete)]));

  testWidgets('profile_form_new', (t) => snapshot(t, 'profile_form_new', const ProfileFormPage(),
      size: const Size(390, 950),
      interact: (t) async {
        await t.tap(find.text('Continue'));
        await t.pump(const Duration(milliseconds: 300));
      },
      overrides: [
        authRepositoryProvider.overrideWithValue(
            FakeAuthRepository()..user = const User(id: 'u1', phone: '9876543210', name: 'Hardik'))
      ]));

  testWidgets('history', (t) {
    final repo = FakeConsultationRepository()
      ..historyList = [
        _c('s3', 'voice', 'completed', reason: 'user_ended', astro: 'Tara Mehta'),
        _c('s2', 'chat', 'rejected', reason: 'astrologer_busy', astro: 'Acharya Vikram Joshi'),
        _c('s1', 'chat', 'completed', reason: 'user_ended'),
      ];
    return snapshot(t, 'history', const HistoryPage(), overrides: [
      consultationRepositoryProvider.overrideWithValue(repo),
      socketClientProvider.overrideWithValue(FakeSocket()),
    ]);
  });
}

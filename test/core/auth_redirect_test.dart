import 'package:astro_connect/core/router/app_router.dart';
import 'package:astro_connect/core/router/routes.dart';
import 'package:astro_connect/features/auth/domain/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const incomplete = User(id: 'u1', phone: '9876543210', name: 'Asha');
  const complete = User(
      id: 'u1', phone: '9876543210', name: 'Asha',
      dob: '1995-08-15', birthTime: '06:30', birthPlace: 'Pune');

  test('restoring session shows splash', () {
    expect(authRedirect(const AsyncLoading(), Routes.astrologers), Routes.splash);
    expect(authRedirect(const AsyncLoading(), Routes.splash), isNull);
  });

  test('signed out users go to login', () {
    expect(authRedirect(const AsyncData(null), Routes.astrologers), Routes.login);
    expect(authRedirect(const AsyncData(null), Routes.login), isNull);
  });

  test('incomplete profile is forced through setup', () {
    expect(authRedirect(const AsyncData(incomplete), Routes.astrologers), Routes.profileSetup);
    expect(authRedirect(const AsyncData(incomplete), Routes.profileSetup), isNull);
  });

  test('complete users skip auth screens', () {
    expect(authRedirect(const AsyncData(complete), Routes.login), Routes.astrologers);
    expect(authRedirect(const AsyncData(complete), Routes.profileSetup), Routes.astrologers);
    expect(authRedirect(const AsyncData(complete), '/consultation/s1'), isNull);
  });

  const astrologer = User(
      id: 'a1', phone: '9100000001', name: 'Pt. Raghav Sharma',
      role: 'astrologer', astrologerId: 'a1');

  test('astrologers land on their desk, not the consumer app', () {
    expect(authRedirect(const AsyncData(astrologer), Routes.login), Routes.desk);
    expect(authRedirect(const AsyncData(astrologer), Routes.splash), Routes.desk);
    expect(authRedirect(const AsyncData(astrologer), Routes.astrologers), Routes.desk);
    expect(authRedirect(const AsyncData(astrologer), Routes.wallet), Routes.desk);
    expect(authRedirect(const AsyncData(astrologer), Routes.profileSetup), Routes.desk,
        reason: 'astrologers never go through birth-details onboarding');
  });

  test('astrologers can use the desk and the shared consultation screen', () {
    expect(authRedirect(const AsyncData(astrologer), Routes.desk), isNull);
    expect(authRedirect(const AsyncData(astrologer), Routes.deskHistory), isNull);
    expect(authRedirect(const AsyncData(astrologer), Routes.deskProfile), isNull);
    expect(authRedirect(const AsyncData(astrologer), '/consultation/s1'), isNull);
  });

  test('consumers never see the desk', () {
    expect(authRedirect(const AsyncData(complete), Routes.desk), Routes.astrologers);
    expect(authRedirect(const AsyncData(complete), Routes.deskHistory), Routes.astrologers);
  });
}

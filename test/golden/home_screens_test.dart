import 'package:astro_connect/features/astrologers/data/astrologer_repository.dart';
import 'package:astro_connect/features/astrologers/presentation/pages/astrologer_detail_page.dart';
import 'package:astro_connect/features/astrologers/presentation/pages/astrologer_list_page.dart';
import 'package:astro_connect/features/auth/data/auth_repository_impl.dart';
import 'package:astro_connect/features/auth/domain/user.dart';
import 'package:astro_connect/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'harness.dart';

const _user = User(
  id: 'u1',
  phone: '9876543210',
  name: 'Hardik Dagli',
  dob: '1995-08-15',
  birthTime: '06:30',
  birthPlace: 'Pune, Maharashtra',
);

void main() {
  final overrides = [
    authRepositoryProvider.overrideWithValue(FakeAuthRepository()..user = _user),
    astrologerRepositoryProvider.overrideWithValue(FakeAstrologerRepository()),
    walletProvider.overrideWith(() => FakeWalletNotifier(balance: 250)),
  ];

  testWidgets('detail', (t) => snapshot(t, 'detail', const AstrologerDetailPage(id: 'a1'),
      overrides: overrides, size: const Size(390, 1100)));

  testWidgets('detail_busy', (t) => snapshot(t, 'detail_busy', const AstrologerDetailPage(id: 'a3'),
      overrides: overrides));

  testWidgets('home', (t) => snapshot(t, 'home', const AstrologerListPage(), overrides: overrides));
}

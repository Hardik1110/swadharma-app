import 'package:astro_connect/core/errors/app_exception.dart';
import 'package:astro_connect/core/network/realtime_providers.dart';
import 'package:astro_connect/core/storage/session_storage.dart';
import 'package:astro_connect/core/theme/app_theme.dart';
import 'package:astro_connect/features/consultation/domain/consultation.dart';
import 'package:astro_connect/features/consultation/presentation/widgets/session_meter.dart';
import 'package:astro_connect/features/wallet/data/wallet_repository.dart';
import 'package:astro_connect/features/wallet/domain/wallet.dart';
import 'package:astro_connect/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:astro_connect/features/wallet/presentation/widgets/top_up_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/load_fonts.dart';
import '../helpers.dart';

class FakeWalletRepository implements WalletRepository {
  int balance = 100;
  final loads = <int>[];

  @override
  Future<Wallet> load() async {
    loads.add(balance);
    return Wallet(balance: balance);
  }

  @override
  Future<Wallet> topUp(int amount) async {
    if (amount < 10) throw const AppException('Enter an amount between ₹10 and ₹10000');
    balance += amount;
    return Wallet(balance: balance);
  }
}

void main() {
  group('WalletNotifier', () {
    late FakeWalletRepository repo;
    late FakeSocket socket;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'auth_token': 'token'});
      final prefs = await SharedPreferences.getInstance();
      repo = FakeWalletRepository();
      socket = FakeSocket();
      container = ProviderContainer.test(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        walletRepositoryProvider.overrideWithValue(repo),
        socketClientProvider.overrideWithValue(socket),
      ]);
      container.listen(walletProvider, (_, _) {});
      await container.read(walletProvider.future);
    });

    int balance() => container.read(walletProvider).requireValue.balance;

    test('loads the balance', () => expect(balance(), 100));

    test('follows live wallet.updated pushes, then re-syncs the ledger', () async {
      repo.balance = 75; // server already charged
      socket.emit('wallet.updated', {'balance': 75});
      await pumpEventQueue();
      expect(balance(), 75, reason: 'updated immediately from the push');

      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(repo.loads.length, 2, reason: 'debounced refetch of the ledger');
    });

    test('top-up credits the wallet; errors surface', () async {
      await container.read(walletProvider.notifier).topUp(500);
      expect(balance(), 600);
      await expectLater(container.read(walletProvider.notifier).topUp(5),
          throwsA(isA<AppException>()));
      expect(balance(), 600);
    });

    test('signed-out users get an empty wallet without a request', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final loggedOut = ProviderContainer.test(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        walletRepositoryProvider.overrideWithValue(repo),
        socketClientProvider.overrideWithValue(socket),
      ]);
      loggedOut.listen(walletProvider, (_, _) {});
      final w = await loggedOut.read(walletProvider.future);
      expect(w.balance, 0);
      expect(repo.loads.length, 1, reason: 'only the logged-in container loaded');
    });
  });

  group('TopUpSheet', () {
    Future<FakeWalletNotifier> open(WidgetTester tester, {int? needed}) async {
      await loadAppFonts();
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final wallet = FakeWalletNotifier(balance: 5);
      await tester.pumpWidget(ProviderScope(
        overrides: [walletProvider.overrideWith(() => wallet)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showTopUpSheet(context, needed: needed),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return wallet;
    }

    testWidgets('pre-selects the smallest amount that covers what is needed', (tester) async {
      final wallet = await open(tester, needed: 45);
      expect(find.text('Pay ₹100'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pay_button')));
      await tester.pumpAndSettle();
      expect(wallet.topUps, [100]);
      expect(find.text('Add money'), findsNothing, reason: 'sheet closed after paying');
    });

    testWidgets('custom amount overrides the preset', (tester) async {
      final wallet = await open(tester);
      await tester.enterText(find.byKey(const Key('custom_amount')), '250');
      await tester.pump();
      expect(find.text('Pay ₹250'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pay_button')));
      await tester.pumpAndSettle();
      expect(wallet.topUps, [250]);
    });

    testWidgets('states plainly that the payment is a demo', (tester) async {
      await open(tester);
      expect(find.textContaining('Demo payment'), findsOneWidget);
    });
  });

  group('SessionMeter', () {
    Consultation session({int paidSeconds = 42}) => Consultation.fromJson(
        sessionJson(chargedMinutes: 2, paidFor: Duration(seconds: paidSeconds)));

    Future<void> pump(WidgetTester tester, {required int balance}) async {
      await loadAppFonts();
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [walletProvider.overrideWith(() => FakeWalletNotifier(balance: balance))],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: SessionMeter(session: session())),
        ),
      ));
      await tester.pump();
    }

    testWidgets('shows rate, spend and balance when funded', (tester) async {
      await pump(tester, balance: 200);
      expect(find.byKey(const Key('session_meter')), findsOneWidget);
      expect(find.text('Balance ₹200'), findsOneWidget);
      expect(find.text('Spent ₹50'), findsOneWidget);
      expect(find.byKey(const Key('low_balance_banner')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('warns with a countdown when the next minute cannot be paid', (tester) async {
      await pump(tester, balance: 10); // rate is 25/min
      expect(find.byKey(const Key('low_balance_banner')), findsOneWidget);
      expect(find.textContaining('ends in'), findsOneWidget);
      // Adding money opens the sheet without leaving the session.
      await tester.tap(find.byKey(const Key('low_balance_add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pay_button')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    test('isBalanceLow compares against one minute of the rate', () {
      final s = session();
      expect(isBalanceLow(s, 24), isTrue);
      expect(isBalanceLow(s, 25), isFalse);
      expect(isBalanceLow(s, null), isFalse, reason: 'unknown balance: let the server decide');
    });
  });
}

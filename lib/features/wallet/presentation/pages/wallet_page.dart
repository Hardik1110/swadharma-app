import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_views.dart';
import '../../../../core/widgets/ui.dart';
import '../../domain/wallet.dart';
import '../providers/wallet_provider.dart';
import '../widgets/top_up_sheet.dart';

class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: RefreshIndicator(
        color: AppColors.indigo,
        onRefresh: () => ref.read(walletProvider.notifier).refresh(),
        child: wallet.when(
          skipLoadingOnRefresh: true,
          loading: () => const LoadingView(),
          error: (e, _) => ListView(children: [
            SizedBox(
              height: 400,
              child: ErrorView(error: e, onRetry: () => ref.invalidate(walletProvider)),
            ),
          ]),
          data: (w) => _Content(wallet: w),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        MaxWidth(
          maxWidth: 720,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _BalanceCard(balance: wallet.balance),
            const SizedBox(height: 26),
            SectionTitle('Transactions',
                trailing: Text('${wallet.transactions.length}', style: theme.textTheme.bodySmall)),
            const SizedBox(height: 12),
            if (wallet.transactions.isEmpty)
              const SoftCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: Text('No transactions yet')),
                ),
              )
            else
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < wallet.transactions.length; i++) ...[
                    if (i > 0) const Divider(indent: 70),
                    _TxnTile(txn: wallet.transactions[i]),
                  ],
                ]),
              ),
          ]),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: AppColors.indigo.withValues(alpha: .32),
                blurRadius: 26,
                offset: const Offset(0, 12)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 18, color: Colors.white.withValues(alpha: .75)),
            const SizedBox(width: 8),
            Text('Available balance',
                style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, .25), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              Fmt.money(balance),
              key: ValueKey(balance),
              style: const TextStyle(
                  color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800, height: 1.1),
            ),
          ),
          const SizedBox(height: 6),
          Text('Per-minute charges are deducted live during a consultation.',
              style: TextStyle(color: Colors.white.withValues(alpha: .65), fontSize: 12.5)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('add_money'),
              onPressed: () => showTopUpSheet(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.saffron,
                foregroundColor: AppColors.onSaffron,
                minimumSize: const Size(64, 50),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add money'),
            ),
          ),
        ]),
      );
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.txn});

  final WalletTxn txn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (txn.type) {
      TxnType.topup => (Icons.add_card_rounded, AppColors.success),
      TxnType.bonus => (Icons.card_giftcard_rounded, AppColors.saffron),
      TxnType.charge => (Icons.timer_outlined, AppColors.indigo),
    };
    final title = switch (txn.type) {
      TxnType.topup => 'Money added',
      TxnType.bonus => 'Welcome bonus',
      TxnType.charge => txn.astrologerName ?? 'Consultation',
    };
    final subtitle = txn.type == TxnType.charge
        ? txn.note.contains(': ') ? txn.note.split(': ').last : txn.note
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              [?subtitle, Fmt.shortDateTime(txn.createdAt)].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${txn.isCredit ? '+' : '−'}${Fmt.money(txn.amount.abs())}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15.5,
              color: txn.isCredit ? AppColors.success : AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text('Bal ${Fmt.money(txn.balanceAfter)}', style: theme.textTheme.bodySmall),
        ]),
      ]),
    );
  }
}

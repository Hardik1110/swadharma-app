import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/wallet_provider.dart';

/// "₹75" pill that opens the wallet.
class WalletChip extends ConsumerWidget {
  const WalletChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(walletProvider.select((w) => w.value?.balance));
    return Material(
      color: AppColors.lavender,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: const Key('wallet_chip'),
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push(Routes.wallet),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.indigo),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                balance == null ? '₹–' : Fmt.money(balance),
                key: ValueKey(balance),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.indigo),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

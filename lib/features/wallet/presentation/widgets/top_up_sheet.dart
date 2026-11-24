import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/ui.dart';
import '../providers/wallet_provider.dart';

/// "Add money" sheet. Returns true when money was added.
///
/// [needed] is the minimum amount that unblocks what the user was doing
/// (for example the first minute of a chat); it pre-selects a sensible amount.
Future<bool> showTopUpSheet(
  BuildContext context, {
  int? needed,
  String? reason,
}) async {
  final added = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => TopUpSheet(needed: needed, reason: reason),
  );
  return added ?? false;
}

class TopUpSheet extends ConsumerStatefulWidget {
  const TopUpSheet({super.key, this.needed, this.reason});

  final int? needed;
  final String? reason;

  @override
  ConsumerState<TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends ConsumerState<TopUpSheet> {
  static const _presets = [100, 200, 500, 1000, 2000];

  final _custom = TextEditingController();
  int? _amount;
  bool _paying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final needed = widget.needed;
    // Smallest preset that covers what is needed, else a rounded-up amount.
    _amount = needed == null
        ? 500
        : _presets.firstWhere((p) => p >= needed, orElse: () => ((needed + 99) ~/ 100) * 100);
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final amount = _amount;
    final wallet = ref.read(walletProvider).value;
    if (amount == null) return;
    if (wallet != null && (amount < wallet.minTopUp || amount > wallet.maxTopUp)) {
      setState(() => _error = 'Enter an amount between ${Fmt.money(wallet.minTopUp)} and ${Fmt.money(wallet.maxTopUp)}');
      return;
    }
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      // Simulated checkout so the flow feels like a real payment.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await ref.read(walletProvider.notifier).topUp(amount);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${Fmt.money(amount)} added to your wallet')));
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wallet = ref.watch(walletProvider).value;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + bottomInset),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Add money', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          widget.reason ??
              'Your balance: ${Fmt.money(wallet?.balance ?? 0)}. Charges are deducted per minute during a consultation.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final p in _presets)
            ChoiceChip(
              key: Key('amount_$p'),
              label: Text(Fmt.money(p)),
              selected: _amount == p && _custom.text.isEmpty,
              onSelected: (_) => setState(() {
                _amount = p;
                _custom.clear();
                _error = null;
              }),
            ),
        ]),
        const SizedBox(height: 16),
        TextField(
          key: const Key('custom_amount'),
          controller: _custom,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 5,
          onChanged: (v) => setState(() {
            _amount = int.tryParse(v);
            _error = null;
          }),
          decoration: const InputDecoration(
            hintText: 'Or enter an amount',
            prefixText: '₹ ',
            counterText: '',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13.5)),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.saffronSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(children: [
            Icon(Icons.science_outlined, size: 18, color: Color(0xFF8A4B00)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Demo payment: no real money is charged. A payment gateway plugs in here.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B3A00), height: 1.35),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          key: const Key('pay_button'),
          label: _amount == null || _amount! <= 0 ? 'Enter an amount' : 'Pay ${Fmt.money(_amount!)}',
          icon: Icons.lock_outline_rounded,
          loading: _paying,
          onPressed: _amount == null || _amount! <= 0 ? null : _pay,
        ),
      ]),
    );
  }
}

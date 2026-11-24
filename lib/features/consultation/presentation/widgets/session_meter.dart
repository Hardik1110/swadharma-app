import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../../../wallet/presentation/widgets/top_up_sheet.dart';
import '../../domain/consultation.dart';

/// True when the wallet can't cover another minute of [session].
bool isBalanceLow(Consultation session, int? balance) =>
    balance != null && balance < session.ratePerMinute;

/// Strip under the app bar of an ongoing consultation: rate, live balance and
/// spend so far. Becomes a warning with a countdown when the balance can't
/// cover the next minute.
class SessionMeter extends ConsumerStatefulWidget {
  const SessionMeter({super.key, required this.session});

  final Consultation session;

  @override
  ConsumerState<SessionMeter> createState() => _SessionMeterState();
}

class _SessionMeterState extends ConsumerState<SessionMeter> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final balance = ref.watch(walletProvider.select((w) => w.value?.balance));
    final low = isBalanceLow(s, balance);

    if (low) {
      final left = s.paidSecondsLeft;
      return Container(
        key: const Key('low_balance_banner'),
        width: double.infinity,
        color: AppColors.saffronSoft,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.saffron),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              left > 0
                  ? 'Balance low. This consultation ends in ${Fmt.clock(left)} unless you add money.'
                  : 'Balance low. Ending now…',
              style: const TextStyle(
                  fontSize: 13, height: 1.3, fontWeight: FontWeight.w600, color: Color(0xFF6B3A00)),
            ),
          ),
          TextButton(
            key: const Key('low_balance_add'),
            onPressed: () => showTopUpSheet(context,
                needed: s.ratePerMinute * 5,
                reason: 'Add money to keep talking. Charges continue per minute.'),
            style: TextButton.styleFrom(foregroundColor: AppColors.indigo),
            child: const Text('Add money'),
          ),
        ]),
      );
    }

    return Container(
      key: const Key('session_meter'),
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Text(Fmt.perMinute(s.ratePerMinute),
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        const Text('  ·  ', style: TextStyle(color: AppColors.offline)),
        Text('Spent ${Fmt.money(s.chargedMinutes * s.ratePerMinute)}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        const Spacer(),
        Text(balance == null ? '' : 'Balance ${Fmt.money(balance)}',
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.indigo)),
      ]),
    );
  }
}

/// Astrologer's version of the meter: what this consultation has earned so far.
class EarningStrip extends StatelessWidget {
  const EarningStrip({super.key, required this.session});

  final Consultation session;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('earning_strip'),
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Text(Fmt.perMinute(session.ratePerMinute),
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          const Spacer(),
          Text('Earned ${Fmt.money(session.earning)}',
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.success)),
        ]),
      );
}

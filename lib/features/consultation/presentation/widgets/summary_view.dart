import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/async_views.dart';
import '../../../../core/widgets/ui.dart';
import '../../domain/consultation.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../providers/consultation_controller.dart';
import 'chat_view.dart';

/// Final state of a consultation: outcome, receipt and rating.
class SummaryView extends ConsumerStatefulWidget {
  const SummaryView({super.key, required this.session, required this.onDone});

  final Consultation session;
  final VoidCallback onDone;

  @override
  ConsumerState<SummaryView> createState() => _SummaryViewState();
}

class _SummaryViewState extends ConsumerState<SummaryView> {
  int _rating = 0;
  final _comment = TextEditingController();
  bool _submitting = false;

  static const _ratingWords = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(consultationControllerProvider(widget.session.id).notifier)
          .rate(_rating, _comment.text);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Thanks for your feedback!')));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _transcript() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .85,
          child: ChatView(sessionId: widget.session.id, readOnly: true),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final theme = Theme.of(context);
    final completed = s.status == ConsultationStatus.completed;
    final (icon, color, title) = switch (s.status) {
      ConsultationStatus.completed => (Icons.check_rounded, AppColors.success, 'Consultation complete'),
      ConsultationStatus.rejected => (Icons.do_not_disturb_alt_rounded, AppColors.busy, 'Request declined'),
      ConsultationStatus.missed => (Icons.timer_off_outlined, AppColors.busy, 'No response'),
      ConsultationStatus.cancelled => (Icons.close_rounded, AppColors.offline, 'Request cancelled'),
      _ => (Icons.info_outline_rounded, AppColors.indigo, s.status.label),
    };
    final messageCount = ref
            .watch(consultationControllerProvider(s.id))
            .value
            ?.messages
            .where((m) => m.text.isNotEmpty)
            .length ??
        0;

    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), children: [
        MaxWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .12),
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                    child: Icon(icon, color: Colors.white, size: 34),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(title,
                key: const Key('summary_title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium),
            if (s.endReasonText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(s.endReasonText,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
            ],
            const SizedBox(height: 26),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    AppAvatar(name: s.astrologerName, url: s.astrologerAvatar, size: 48, ring: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.astrologerName,
                            style: const TextStyle(
                                fontFamily: AppTheme.serif,
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${s.type.label} · ${Fmt.dateTime(s.requestedAt)}',
                            style: theme.textTheme.bodySmall),
                      ]),
                    ),
                  ]),
                ),
                if (completed) ...[
                  const Divider(),
                  _Row('Duration', Fmt.duration(s.durationSeconds)),
                  _Row('Rate', Fmt.perMinute(s.ratePerMinute)),
                  Builder(builder: (context) {
                    final balance = ref.watch(walletProvider.select((w) => w.value?.balance));
                    return balance == null ? const SizedBox.shrink() : _Row('Wallet balance', Fmt.money(balance));
                  }),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Row(children: [
                      Text('Total charged', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      Text(Fmt.money(s.cost),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.indigo)),
                    ]),
                  ),
                ],
              ]),
            ),
            if (s.type == ConsultationType.chat && messageCount > 2) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _transcript,
                icon: const Icon(Icons.forum_outlined),
                label: const Text('View conversation'),
              ),
            ],
            if (completed) ...[
              const SizedBox(height: 26),
              SoftCard(
                padding: const EdgeInsets.all(20),
                child: s.rating != null
                    ? Column(children: [
                        Text('Thanks for your rating', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 10),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          for (var i = 1; i <= 5; i++)
                            Icon(i <= s.rating! ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: AppColors.gold, size: 34),
                        ]),
                      ])
                    : Column(children: [
                        Text('How was your consultation?', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text('Your feedback helps other seekers.', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          for (var i = 1; i <= 5; i++)
                            IconButton(
                              key: Key('star_$i'),
                              onPressed: () => setState(() => _rating = i),
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                  i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: AppColors.gold,
                                  size: 40),
                            ),
                        ]),
                        if (_rating > 0) ...[
                          Text(_ratingWords[_rating],
                              style: theme.textTheme.labelLarge?.copyWith(color: AppColors.indigo)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _comment,
                            maxLines: 3,
                            maxLength: 300,
                            decoration: const InputDecoration(
                                hintText: 'Share your experience (optional)'),
                          ),
                          const SizedBox(height: 4),
                          PrimaryButton(
                            label: 'Submit rating',
                            loading: _submitting,
                            onPressed: _submit,
                            height: 52,
                          ),
                        ],
                      ]),
              ),
            ],
            const SizedBox(height: 22),
            PrimaryButton(label: 'Done', onPressed: widget.onDone),
          ]),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
        ]),
      );
}

/// Astrologer's view of a finished consultation: outcome and earnings.
class AstrologerSummaryView extends StatelessWidget {
  const AstrologerSummaryView({super.key, required this.session, required this.onDone});

  final Consultation session;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final theme = Theme.of(context);
    final completed = s.status == ConsultationStatus.completed;
    final (icon, color, title) = switch (s.status) {
      ConsultationStatus.completed => (Icons.check_rounded, AppColors.success, 'Consultation complete'),
      ConsultationStatus.rejected => (Icons.do_not_disturb_alt_rounded, AppColors.busy, 'Request declined'),
      ConsultationStatus.missed => (Icons.timer_off_outlined, AppColors.busy, 'Request missed'),
      ConsultationStatus.cancelled => (Icons.close_rounded, AppColors.offline, 'Request cancelled'),
      _ => (Icons.info_outline_rounded, AppColors.indigo, s.status.label),
    };

    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), children: [
        MaxWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .12)),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                    child: Icon(icon, color: Colors.white, size: 34),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(title,
                key: const Key('summary_title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium),
            if (s.endReasonTextForAstrologer.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(s.endReasonTextForAstrologer,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
            ],
            const SizedBox(height: 26),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    AppAvatar(name: s.userName, size: 48, ring: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.userName,
                            style: const TextStyle(
                                fontFamily: AppTheme.serif,
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${s.type.label} · ${Fmt.dateTime(s.requestedAt)}',
                            style: theme.textTheme.bodySmall),
                      ]),
                    ),
                  ]),
                ),
                if (completed) ...[
                  const Divider(),
                  _Row('Duration', Fmt.duration(s.durationSeconds)),
                  _Row('Charged to customer', Fmt.money(s.cost)),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Row(children: [
                      Text('You earned', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      Text(Fmt.money(s.earning),
                          key: const Key('earned_amount'),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.success)),
                    ]),
                  ),
                ],
              ]),
            ),
            if (completed && s.rating != null) ...[
              const SizedBox(height: 16),
              SoftCard(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  Text('${s.userName.split(' ').first} rated you', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 1; i <= 5; i++)
                      Icon(i <= s.rating! ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: AppColors.gold, size: 32),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 22),
            PrimaryButton(label: 'Back to requests', onPressed: onDone),
          ]),
        ),
      ]),
    );
  }
}

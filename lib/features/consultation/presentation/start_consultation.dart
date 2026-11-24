import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/async_views.dart';
import '../../astrologers/domain/astrologer.dart';
import '../../wallet/presentation/providers/wallet_provider.dart';
import '../../wallet/presentation/widgets/top_up_sheet.dart';
import '../data/consultation_repository.dart';
import '../domain/consultation.dart';
import 'providers/call_controller.dart';
import 'providers/consultation_controller.dart';

/// Confirms, checks permissions, creates the session and opens it.
Future<void> startConsultation(
  BuildContext context,
  WidgetRef ref,
  Astrologer astrologer,
  ConsultationType type,
) async {
  final ok = await showConsultationConfirmSheet(context, astrologer, type);
  if (ok != true || !context.mounted) return;
  await _begin(context, ref, astrologer, type);
}

/// Permissions, then create the session on the server and open it.
Future<void> _begin(
  BuildContext context,
  WidgetRef ref,
  Astrologer astrologer,
  ConsultationType type,
) async {
  if (type.isCall &&
      !await CallController.ensurePermissions(video: type == ConsultationType.video)) {
    if (!context.mounted) return;
    final open = await confirm(
      context,
      title: 'Permission needed',
      message: type == ConsultationType.video
          ? 'Allow camera and microphone access to start a video consultation.'
          : 'Allow microphone access to start a voice consultation.',
      confirmLabel: 'Open settings',
    );
    if (open) await openAppSettings();
    return;
  }

  try {
    final session =
        await ref.read(consultationRepositoryProvider).start(astrologer.id, type);
    ref.invalidate(consultationHistoryProvider);
    if (context.mounted) context.push(Routes.consultation(session.id));
  } on AppException catch (e) {
    if (!context.mounted) return;
    if (e.code == 'insufficient_balance') {
      final price = astrologer.pricing[type.name] ?? 0;
      final balance = ref.read(walletProvider).value?.balance ?? 0;
      final added = await showTopUpSheet(
        context,
        needed: (price - balance).clamp(1, 1 << 20),
        reason: e.message,
      );
      if (added && context.mounted) await _begin(context, ref, astrologer, type);
      return;
    }
    // Calls can't be taken right now (no live astrologer, demo line in use, or
    // the demo token expired): explain, and offer chat.
    const callsUnavailable = {'astrologer_not_live', 'call_line_busy', 'call_token_expired'};
    if (callsUnavailable.contains(e.code)) {
      final chatInstead = await showNotLiveDialog(context, astrologer, type, e.message);
      if (chatInstead && context.mounted) {
        await startConsultation(context, ref, astrologer, ConsultationType.chat);
      }
      return;
    }
    if (e.code == 'session_active') {
      final history = await ref.read(consultationRepositoryProvider).history();
      final active = history.where((c) => c.status.isActive).firstOrNull;
      if (!context.mounted) return;
      if (active != null &&
          await confirm(context,
              title: 'Consultation in progress',
              message:
                  'You already have a ${active.type.label.toLowerCase()} with ${active.astrologerName}.',
              confirmLabel: 'Open it')) {
        if (context.mounted) context.push(Routes.consultation(active.id));
      }
      return;
    }
    showError(context, e);
  }
}

/// Shown when a voice/video call can't be taken right now. Returns true when
/// the user picks "Chat instead".
Future<bool> showNotLiveDialog(
  BuildContext context,
  Astrologer astrologer,
  ConsultationType type,
  String message,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle),
        child: Icon(
          type == ConsultationType.video ? Icons.videocam_off_rounded : Icons.phone_disabled_rounded,
          color: AppColors.indigo,
        ),
      ),
      title: Text('${type == ConsultationType.video ? 'Video' : 'Voice'} call unavailable',
          textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        PrimaryButton(
          key: const Key('chat_instead'),
          label: 'Chat instead',
          icon: Icons.chat_bubble_rounded,
          height: 50,
          onPressed: () => Navigator.pop(ctx, true),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
      ],
    ),
  );
  return result ?? false;
}

/// "Start a chat with ...?" sheet. Scrolls and grows as needed, so it never
/// overflows on small screens or with large system text.
Future<bool?> showConsultationConfirmSheet(
  BuildContext context,
  Astrologer astrologer,
  ConsultationType type,
) =>
    showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ConfirmSheet(astrologer: astrologer, type: type),
    );

class _ConfirmSheet extends ConsumerWidget {
  const _ConfirmSheet({required this.astrologer, required this.type});

  final Astrologer astrologer;
  final ConsultationType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final price = astrologer.pricing[type.name] ?? 0;
    final balance = ref.watch(walletProvider.select((w) => w.value?.balance));
    // While the wallet is loading, let the server decide.
    final short = balance != null && balance < price;
    final first = astrologer.name.split(' ').where((p) => !p.endsWith('.')).firstOrNull ??
        astrologer.name;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AppAvatar(name: astrologer.name, url: astrologer.avatarUrl, size: 76, ring: true),
          const SizedBox(height: 14),
          Text('${type.label} with', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(astrologer.name,
              textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 18),
          _Line(Icons.payments_outlined, '${Fmt.perMinute(price)}, billed per started minute'),
          _Line(
            short ? Icons.warning_amber_rounded : Icons.account_balance_wallet_outlined,
            short
                ? 'Your balance is ${Fmt.money(balance)}. Add at least ${Fmt.money(price - balance)} to start.'
                : balance == null
                    ? 'Checking your wallet…'
                    : 'Wallet balance ${Fmt.money(balance)}, charged live each minute',
            highlight: short,
          ),
          _Line(Icons.hourglass_top_rounded, '$first has 60 seconds to accept your request'),
          _Line(Icons.badge_outlined, 'Your birth details are shared with the astrologer'),
          const SizedBox(height: 22),
          if (short)
            PrimaryButton(
              key: const Key('add_money_to_start'),
              label: 'Add money',
              icon: Icons.add_rounded,
              height: 52,
              onPressed: () => showTopUpSheet(context, needed: price - balance, reason:
                  'You need at least ${Fmt.money(price)} to start. Your balance is ${Fmt.money(balance)}.'),
            )
          else
            PrimaryButton(
              key: const Key('confirm_start'),
              label:
                  'Start ${type == ConsultationType.chat ? 'chat' : type == ConsultationType.voice ? 'call' : 'video'}',
              icon: type.icon,
              height: 52,
              onPressed: () => Navigator.pop(context, true),
            ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
        ]),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text, {this.highlight = false});
  final IconData icon;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: highlight ? AppColors.saffronSoft : AppColors.lavender,
                shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: highlight ? AppColors.saffron : AppColors.indigo),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w400)),
          ),
        ]),
      );
}

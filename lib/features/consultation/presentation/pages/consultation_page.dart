import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/async_views.dart';
import '../../domain/chat_message.dart';
import '../../domain/consultation.dart';
import '../providers/consultation_controller.dart';
import '../widgets/birth_details.dart';
import '../widgets/call_view.dart';
import '../widgets/chat_view.dart';
import '../widgets/incoming_request_view.dart';
import '../widgets/session_meter.dart';
import '../widgets/session_widgets.dart';
import '../widgets/summary_view.dart';
import '../widgets/waiting_view.dart';

/// One screen for the whole consultation lifecycle, for both sides of it.
///
/// Customer: waiting -> chat/call -> summary.
/// Astrologer: incoming request -> chat/call -> earnings summary.
class ConsultationPage extends ConsumerWidget {
  const ConsultationPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(consultationControllerProvider(sessionId));
    final ctrl = ref.read(consultationControllerProvider(sessionId).notifier);
    final asAstrologer = ref.watch(viewerSenderProvider) == MessageSender.astrologer;

    final session = async.value?.session;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.hasError
            ? ErrorView(
                error: async.error!,
                onRetry: () => ref.invalidate(consultationControllerProvider(sessionId)))
            : const LoadingView(message: 'Loading consultation…'),
      );
    }

    Future<void> guarded(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    final requested = session.status == ConsultationStatus.requested;
    final ongoing = session.status == ConsultationStatus.ongoing;

    /// Asks before ending a live consultation; returns true when the user may
    /// leave the screen.
    Future<bool> confirmLeave() async {
      // An astrologer can step away from a pending request: it stays waiting.
      if (asAstrologer && requested) return true;
      final ok = await confirm(
        context,
        title: requested ? 'Cancel request?' : 'End consultation?',
        message: requested
            ? '${session.astrologerName} hasn\'t accepted yet.'
            : asAstrologer
                ? '${session.userName} will be charged for the time used so far.'
                : 'You will be charged for the time used so far.',
        confirmLabel: requested ? 'Cancel request' : 'End',
        cancelLabel: requested ? 'Keep waiting' : 'Continue',
        destructive: true,
      );
      if (!ok) return false;
      await guarded(requested ? ctrl.cancelRequest : ctrl.end);
      return true;
    }

    void done() => context.canPop()
        ? context.pop()
        : context.go(asAstrologer ? Routes.desk : Routes.astrologers);

    final active = session.status.isActive;
    final isCall = session.type.isCall && ongoing;
    // The customer's waiting screen and calls use the dark, full-screen look.
    final fullBleed = isCall || (requested && !asAstrologer);
    final mustConfirmLeave = active && !(asAstrologer && requested);

    final Widget body = switch (session.status) {
      ConsultationStatus.requested when asAstrologer => IncomingRequestView(
          session: session,
          onAccept: () => guarded(ctrl.accept),
          onDecline: () => guarded(ctrl.reject),
        ),
      ConsultationStatus.requested => WaitingView(
          session: session,
          onCancel: () => guarded(ctrl.cancelRequest),
          onClose: () async {
            if (await confirmLeave() && context.mounted) done();
          },
        ),
      ConsultationStatus.ongoing when session.type == ConsultationType.chat =>
        ChatView(sessionId: sessionId),
      ConsultationStatus.ongoing => CallView(
          session: session,
          onEnd: (reason) => guarded(() => ctrl.end(reason: reason)),
        ),
      _ => asAstrologer
          ? AstrologerSummaryView(session: session, onDone: done)
          : SummaryView(session: session, onDone: done),
    };

    return PopScope(
      canPop: !mustConfirmLeave,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmLeave() && context.mounted) done();
      },
      child: Scaffold(
        backgroundColor: fullBleed ? AppColors.indigoDeep : null,
        appBar: fullBleed
            ? null
            : AppBar(
                titleSpacing: 0,
                backgroundColor: Colors.white,
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: mustConfirmLeave
                      ? () async {
                          if (await confirmLeave() && context.mounted) done();
                        }
                      : done,
                ),
                shape: const Border(bottom: BorderSide(color: AppColors.hairline)),
                toolbarHeight: 68,
                title: ongoing
                    ? _ChatTitle(
                        sessionId: sessionId, session: session, asAstrologer: asAstrologer)
                    : Text(requested ? 'New request' : 'Consultation summary'),
                actions: [
                  if (ongoing) ...[
                    if (asAstrologer)
                      IconButton(
                        key: const Key('birth_details_button'),
                        tooltip: 'Birth details',
                        icon: const Icon(Icons.auto_awesome_outlined, color: AppColors.indigo),
                        onPressed: () => _showBirthDetails(context, session),
                      ),
                    SessionTimerChip(seconds: () => session.elapsedSeconds),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: OutlinedButton(
                        key: const Key('end_session'),
                        onPressed: confirmLeave,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: Color(0xFFF1C5CB), width: 1.4),
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('End'),
                      ),
                    ),
                  ],
                ],
              ),
        body: fullBleed
            ? Stack(children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(key: ValueKey(session.status), child: body),
                  ),
                ),
                if (active)
                  const SafeArea(
                      child: Align(
                          alignment: Alignment.topCenter,
                          child: ConnectionBanner(floating: true))),
              ])
            : Column(children: [
                if (active) const ConnectionBanner(),
                if (ongoing)
                  asAstrologer ? EarningStrip(session: session) : SessionMeter(session: session),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(key: ValueKey(session.status), child: body),
                  ),
                ),
              ]),
      ),
    );
  }

  /// The customer's birth data, one tap away during a consultation.
  void _showBirthDetails(BuildContext context, Consultation session) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.userName, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('Birth details', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              BirthDetails(session: session),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTitle extends ConsumerWidget {
  const _ChatTitle({
    required this.sessionId,
    required this.session,
    required this.asAstrologer,
  });

  final String sessionId;
  final Consultation session;
  final bool asAstrologer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typing = ref.watch(
        consultationControllerProvider(sessionId).select((s) => s.value?.peerTyping ?? false));
    final theme = Theme.of(context);
    final name = session.peerName(asAstrologer: asAstrologer);
    return Row(children: [
      AppAvatar(
        name: name,
        url: session.peerAvatar(asAstrologer: asAstrologer),
        size: 38,
        statusColor: AppColors.success,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: AppTheme.serif,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2)),
          Text(typing ? 'typing…' : asAstrologer ? 'Customer' : 'Online',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: typing ? AppColors.indigo : AppColors.success,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    ]);
  }
}

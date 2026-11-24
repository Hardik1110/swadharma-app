import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/chat_message.dart';
import '../providers/consultation_controller.dart';

/// Message list + composer. Read-only (no composer) once the session ends.
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key, required this.sessionId, this.readOnly = false});

  final String sessionId;
  final bool readOnly;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text;
    if (text.trim().isEmpty) return;
    ref.read(consultationControllerProvider(widget.sessionId).notifier).sendMessage(text);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(consultationControllerProvider(widget.sessionId)).value;
    if (state == null) return const SizedBox.shrink();
    final messages = state.messages;
    final viewer = ref.watch(viewerSenderProvider);
    final ctrl = ref.read(consultationControllerProvider(widget.sessionId).notifier);

    // Newest at the bottom: reversed list keeps the view pinned to the end.
    final items = <Object>[
      if (state.peerTyping) const _Typing(),
      ...messages.reversed,
    ];

    return Column(children: [
      Expanded(
        child: messages.isEmpty && !state.peerTyping
            ? const _EmptyChat()
            : ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  if (item is _Typing) return item;
                  final m = item as ChatMessage;
                  final older = i + 1 < items.length ? items[i + 1] : null;
                  final showDay = older is! ChatMessage ||
                      Fmt.day(older.sentAt) != Fmt.day(m.sentAt);
                  return Column(children: [
                    if (showDay) _DayDivider(Fmt.day(m.sentAt)),
                    _Bubble(message: m, mine: m.sender == viewer, onRetry: () => ctrl.retry(m)),
                  ]);
                },
              ),
      ),
      if (!widget.readOnly)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: AppColors.indigo.withValues(alpha: .08),
                  blurRadius: 20,
                  offset: const Offset(0, -4)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: TextField(
                    key: const Key('chat_input'),
                    controller: _text,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => ctrl.userTyping(),
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(fontSize: 15.5),
                    decoration: InputDecoration(
                      hintText: viewer == MessageSender.astrologer ? 'Type your reply…' : 'Ask your question…',
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.ivory,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.indigo, width: 1.2)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: _text.text.trim().isEmpty ? null : AppColors.ctaGradient,
                    color: _text.text.trim().isEmpty ? AppColors.hairline : null,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    key: const Key('chat_send'),
                    onPressed: _send,
                    icon: Icon(Icons.arrow_upward_rounded,
                        color: _text.text.trim().isEmpty ? AppColors.muted : Colors.white),
                  ),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.indigo, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Say hello', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('Ask about career, relationships, health or anything on your mind.',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ]),
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.onRetry});

  final ChatMessage message;

  /// Sent by the person looking at the screen.
  final bool mine;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final theme = Theme.of(context);

    if (m.sender == MessageSender.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(m.text,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.indigo, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ),
      );
    }

    final fg = mine ? Colors.white : AppColors.ink;
    final meta = mine ? Colors.white.withValues(alpha: .7) : AppColors.muted;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 7),
      decoration: BoxDecoration(
        gradient: mine ? AppColors.ctaGradient : null,
        color: mine ? null : Colors.white,
        border: mine ? null : Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
              color: (mine ? AppColors.indigo : Colors.black).withValues(alpha: mine ? .18 : .04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(mine ? 20 : 6),
          bottomRight: Radius.circular(mine ? 6 : 20),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(m.text, style: TextStyle(color: fg, fontSize: 15.5, height: 1.4)),
        const SizedBox(height: 3),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(Fmt.time(m.sentAt), style: TextStyle(color: meta, fontSize: 11)),
          if (mine) ...[
            const SizedBox(width: 4),
            Icon(
              switch (m.delivery) {
                DeliveryState.sending => Icons.schedule_rounded,
                DeliveryState.sent => Icons.done_all_rounded,
                DeliveryState.failed => Icons.error_outline_rounded,
              },
              size: 14,
              color: m.delivery == DeliveryState.failed ? const Color(0xFFFFB4BC) : meta,
            ),
          ],
        ]),
      ]),
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: m.delivery == DeliveryState.failed
          ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              bubble,
              TextButton.icon(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger, visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Not sent · Tap to retry'),
              ),
            ])
          : bubble,
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.hairline,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
          ),
        ),
      );
}

/// Three bouncing dots in a bubble.
class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.hairline),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
            ),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 3; i++)
                Container(
                  margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.indigo.withValues(
                        alpha: .25 + .6 * (1 - ((_c.value * 3 - i) % 3) / 3).clamp(0, 1)),
                  ),
                ),
            ]),
          ),
        ),
      );
}

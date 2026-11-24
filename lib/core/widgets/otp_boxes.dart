import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Six (by default) separate digit boxes backed by one invisible text field,
/// so typing, deleting, pasting and SMS autofill all work normally.
class OtpBoxes extends StatelessWidget {
  const OtpBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    this.length = 6,
    this.hasError = false,
    this.enabled = true,
    this.onChanged,
    this.onCompleted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, focusNode]),
      builder: (context, _) {
        final text = controller.text;
        final active = text.length.clamp(0, length - 1);
        return SizedBox(
          height: 60,
          child: Stack(children: [
            Row(children: [
              for (var i = 0; i < length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _Box(
                    char: i < text.length ? text[i] : '',
                    focused: focusNode.hasFocus && i == active && enabled,
                    filled: i < text.length,
                    hasError: hasError,
                    scheme: scheme,
                  ),
                ),
              ],
            ]),
            // Invisible field on top: captures taps, keyboard and autofill.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  key: const Key('otp_field'),
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: length,
                  showCursor: false,
                  enableSuggestions: false,
                  autocorrect: false,
                  enableInteractiveSelection: false,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                  onChanged: (v) {
                    onChanged?.call(v);
                    if (v.length == length) onCompleted?.call(v);
                  },
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.char,
    required this.focused,
    required this.filled,
    required this.hasError,
    required this.scheme,
  });

  final String char;
  final bool focused;
  final bool filled;
  final bool hasError;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? scheme.error
        : focused
            ? scheme.primary
            : filled
                ? scheme.primary.withValues(alpha: .5)
                : scheme.outlineVariant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: focused || hasError ? 2 : 1),
      ),
      child: Text(
        char,
        style: Theme.of(context)
            .textTheme
            .headlineSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

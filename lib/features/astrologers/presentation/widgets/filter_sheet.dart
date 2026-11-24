import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ui.dart';

import '../../domain/astrologer.dart';

/// Bottom sheet for expertise, language, availability and sort.
Future<AstrologerFilter?> showFilterSheet(
  BuildContext context, {
  required AstrologerFilter initial,
  required List<String> expertise,
}) =>
    showModalBottomSheet<AstrologerFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(initial: initial, expertise: expertise),
    );

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.expertise});

  final AstrologerFilter initial;
  final List<String> expertise;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late var _f = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget title(String t) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 10),
          child: Text(t, style: theme.textTheme.titleMedium),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('Filters', style: theme.textTheme.titleLarge),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _f = AstrologerFilter(query: _f.query)),
              child: const Text('Reset'),
            ),
          ]),
          Flexible(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SwitchListTile(
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.indigo,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available now'),
                  subtitle: const Text('Show only online astrologers'),
                  value: _f.onlineOnly,
                  onChanged: (v) => setState(() => _f = _f.copyWith(onlineOnly: v)),
                ),
                title('Sort by'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in AstrologerSort.values)
                    ChoiceChip(
                      label: Text(s.label),
                      labelStyle: TextStyle(
                          color: _f.sort == s ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w600),
                      selected: _f.sort == s,
                      onSelected: (_) => setState(() => _f = _f.copyWith(sort: s)),
                    ),
                ]),
                title('Expertise'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in widget.expertise)
                    FilterChip(
                      label: Text(e),
                      labelStyle: TextStyle(
                          color: _f.expertise == e ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w600),
                      selected: _f.expertise == e,
                      onSelected: (sel) =>
                          setState(() => _f = _f.copyWith(expertise: () => sel ? e : null)),
                    ),
                ]),
                title('Language'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final l in kLanguages)
                    FilterChip(
                      label: Text(l),
                      labelStyle: TextStyle(
                          color: _f.language == l ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w600),
                      selected: _f.language == l,
                      onSelected: (sel) =>
                          setState(() => _f = _f.copyWith(language: () => sel ? l : null)),
                    ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Apply filters',
            onPressed: () => Navigator.pop(context, _f),
          ),
        ],
      ),
    );
  }
}

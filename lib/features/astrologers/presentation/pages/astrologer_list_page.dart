import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/async_views.dart';
import '../../../../core/widgets/ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../wallet/presentation/widgets/wallet_chip.dart';
import '../../domain/astrologer.dart';
import '../providers/astrologer_providers.dart';
import '../widgets/astrologer_card.dart';
import '../widgets/filter_sheet.dart';

const _categoryIcons = <String, IconData>{
  'Vedic': Icons.auto_awesome_rounded,
  'Tarot': Icons.style_rounded,
  'Numerology': Icons.tag_rounded,
  'Vastu': Icons.home_work_outlined,
  'Palmistry': Icons.back_hand_outlined,
  'KP': Icons.timeline_rounded,
  'Love & Relationship': Icons.favorite_border_rounded,
  'Career': Icons.work_outline_rounded,
  'Face Reading': Icons.face_retouching_natural_outlined,
};

class AstrologerListPage extends ConsumerStatefulWidget {
  const AstrologerListPage({super.key});

  @override
  ConsumerState<AstrologerListPage> createState() => _AstrologerListPageState();
}

class _AstrologerListPageState extends ConsumerState<AstrologerListPage> {
  late final _search =
      TextEditingController(text: ref.read(astrologerFilterProvider).query);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350),
        () => ref.read(astrologerFilterProvider.notifier).setQuery(q));
    setState(() {});
  }

  Future<void> _openFilters() async {
    final config = ref.read(appConfigProvider).value;
    final result = await showFilterSheet(
      context,
      initial: ref.read(astrologerFilterProvider),
      expertise: config?.expertise ?? const [],
    );
    if (result != null) ref.read(astrologerFilterProvider.notifier).apply(result);
  }

  void _clearAll() {
    _search.clear();
    ref.read(astrologerFilterProvider.notifier)
      ..reset()
      ..setQuery('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(astrologerFilterProvider);
    final list = ref.watch(astrologerListProvider);
    final presence = ref.watch(presenceProvider);
    final expertise = ref.watch(appConfigProvider).value?.expertise ?? const <String>[];
    final user = ref.watch(authProvider).value;
    final theme = Theme.of(context);

    final browsing =
        filter.activeCount == 0 && filter.expertise == null && filter.query.isEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.indigo,
          onRefresh: () => ref.refresh(astrologerListProvider.future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Greeting
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Namaste 🙏',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.muted)),
                        const SizedBox(height: 2),
                        Text(
                          user == null || user.name.isEmpty
                              ? 'Find your astrologer'
                              : user.firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineMedium,
                        ),
                      ]),
                    ),
                    const WalletChip(),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => context.go(Routes.profile),
                      child: AppAvatar(name: user?.name ?? '', size: 44),
                    ),
                  ]),
                ),
              ),
              // Search
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: _SearchBar(
                    controller: _search,
                    onChanged: _onSearch,
                    onClear: () {
                      _search.clear();
                      _onSearch('');
                    },
                    onFilters: _openFilters,
                    activeFilters: filter.activeCount,
                  ),
                ),
              ),
              // Categories
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 74,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                    children: [
                      _CategoryChip(
                        label: 'All',
                        icon: Icons.apps_rounded,
                        selected: filter.expertise == null,
                        onTap: () =>
                            ref.read(astrologerFilterProvider.notifier).setExpertise(null),
                      ),
                      for (final e in expertise)
                        _CategoryChip(
                          label: e,
                          icon: _categoryIcons[e] ?? Icons.auto_awesome_rounded,
                          selected: filter.expertise == e,
                          onTap: () => ref
                              .read(astrologerFilterProvider.notifier)
                              .setExpertise(filter.expertise == e ? null : e),
                        ),
                    ],
                  ),
                ),
              ),
              // Online now
              if (browsing && list.hasValue)
                SliverToBoxAdapter(
                  child: _OnlineNow(
                    astrologers: [
                      for (final a in list.requireValue)
                        if ((presence[a.id] ?? a.status) == AstrologerStatus.online) a,
                    ],
                  ),
                ),
              // Section header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: SectionTitle(
                    filter.query.isNotEmpty || filter.expertise != null
                        ? 'Results'
                        : 'All astrologers',
                    trailing: list.hasValue
                        ? Text('${list.requireValue.length} available',
                            style: theme.textTheme.bodySmall)
                        : null,
                  ),
                ),
              ),
              ...list.when(
                skipLoadingOnRefresh: true,
                loading: () => [const SliverFillRemaining(hasScrollBody: false, child: LoadingView())],
                error: (e, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorView(
                        error: e, onRetry: () => ref.invalidate(astrologerListProvider)),
                  ),
                ],
                data: (items) => items.isEmpty
                    ? [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyView(
                            icon: Icons.person_search_rounded,
                            title: 'No astrologers found',
                            subtitle: 'Try a different search or clear your filters',
                            action: OutlinedButton(
                              onPressed: _clearAll,
                              child: const Text('Clear filters'),
                            ),
                          ),
                        ),
                      ]
                    : [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                          sliver: SliverGrid.builder(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 520,
                              mainAxisExtent: 190,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                            ),
                            itemCount: items.length,
                            itemBuilder: (_, i) => AstrologerCard(
                              astrologer: items[i],
                              onTap: () => context.push(Routes.astrologer(items[i].id)),
                            ),
                          ),
                        ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onFilters,
    required this.activeFilters,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onFilters;
  final int activeFilters;

  @override
  Widget build(BuildContext context) => Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.hairline),
          boxShadow: [
            BoxShadow(
                color: AppColors.indigo.withValues(alpha: .06),
                blurRadius: 20,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, right: 10),
            child: Icon(Icons.search_rounded, color: AppColors.muted),
          ),
          Expanded(
            child: TextField(
              key: const Key('search_field'),
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 15.5),
              decoration: const InputDecoration(
                hintText: 'Search name, skill or language',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppColors.muted,
              onPressed: onClear,
            ),
          Container(width: 1, height: 26, color: AppColors.hairline),
          Badge(
            isLabelVisible: activeFilters > 0,
            label: Text('$activeFilters'),
            backgroundColor: AppColors.saffron,
            textColor: AppColors.onSaffron,
            offset: const Offset(-6, 4),
            child: IconButton(
              key: const Key('filter_button'),
              onPressed: onFilters,
              icon: const Icon(Icons.tune_rounded),
              color: AppColors.indigo,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        ]),
      );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.ctaGradient : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? Colors.transparent : AppColors.hairline),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: AppColors.indigo.withValues(alpha: .25),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 17, color: selected ? Colors.white : AppColors.indigo),
                  const SizedBox(width: 7),
                  Text(label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.ink,
                      )),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Story-style row of astrologers who are available right now.
class _OnlineNow extends StatelessWidget {
  const _OnlineNow({required this.astrologers});

  final List<Astrologer> astrologers;

  @override
  Widget build(BuildContext context) {
    if (astrologers.length < 2) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('Online now', style: theme.textTheme.titleLarge),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 98,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: astrologers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final a = astrologers[i];
              final first = a.name.split(' ').where((p) => !p.endsWith('.')).firstOrNull ??
                  a.name.split(' ').first;
              return GestureDetector(
                onTap: () => context.push(Routes.astrologer(a.id)),
                child: SizedBox(
                  width: 68,
                  child: Column(children: [
                    AppAvatar(
                        name: a.name,
                        url: a.avatarUrl,
                        size: 66,
                        ring: true,
                        statusColor: AppColors.success),
                    const SizedBox(height: 7),
                    Text(first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}


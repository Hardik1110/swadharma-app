import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/realtime_providers.dart';
import '../../../../core/network/socket_client.dart';
import '../../data/astrologer_repository.dart';
import '../../domain/astrologer.dart';

final appConfigProvider = FutureProvider<AppConfig>(
    (ref) => ref.watch(astrologerRepositoryProvider).config());

final astrologerFilterProvider =
    NotifierProvider<AstrologerFilterNotifier, AstrologerFilter>(
        AstrologerFilterNotifier.new);

class AstrologerFilterNotifier extends Notifier<AstrologerFilter> {
  @override
  AstrologerFilter build() => const AstrologerFilter();

  void setQuery(String q) => state = state.copyWith(query: q);
  void setExpertise(String? e) => state = state.copyWith(expertise: () => e);
  void apply(AstrologerFilter f) => state = f.copyWith(query: state.query);
  void reset() => state = AstrologerFilter(query: state.query);
}

/// Server-side search/filter results for the current filter.
final astrologerListProvider = FutureProvider.autoDispose<List<Astrologer>>((ref) {
  final filter = ref.watch(astrologerFilterProvider);
  return ref.watch(astrologerRepositoryProvider).list(filter);
});

final astrologerDetailProvider = FutureProvider.autoDispose
    .family<Astrologer, String>((ref, id) => ref.watch(astrologerRepositoryProvider).get(id));

/// Live presence pushed over the socket (`astrologer.status`), layered on top
/// of whatever the last REST fetch returned.
final presenceProvider =
    NotifierProvider<PresenceNotifier, Map<String, AstrologerStatus>>(PresenceNotifier.new);

class PresenceNotifier extends Notifier<Map<String, AstrologerStatus>> {
  @override
  Map<String, AstrologerStatus> build() {
    // Events may have been missed while offline: drop overrides and refetch.
    ref.listen(socketStatusProvider, (prev, next) {
      if (next == SocketStatus.connected && prev != SocketStatus.connected) {
        state = const {};
        ref.invalidate(astrologerListProvider);
      }
    });
    final sub = ref.watch(socketClientProvider).events.listen((e) {
      if (e.type != 'astrologer.status') return;
      state = {
        ...state,
        e.data['astrologerId'] as String: AstrologerStatus.parse(e.data['status'] as String?),
      };
    });
    ref.onDispose(sub.cancel);
    return const {};
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../consultation/data/consultation_repository.dart';
import '../../../consultation/domain/consultation.dart';
import '../../../consultation/presentation/providers/consultation_controller.dart';
import '../../data/desk_repository.dart';
import '../../domain/desk.dart';

/// The astrologer's profile and totals. Refetched whenever their consultations
/// change, so earnings update the moment a session ends.
final deskProfileProvider = FutureProvider.autoDispose<DeskProfile>((ref) {
  ref.watch(consultationHistoryProvider);
  return ref.watch(deskRepositoryProvider).me();
});

/// Requests waiting for this astrologer, oldest first.
final pendingRequestsProvider = Provider.autoDispose<List<Consultation>>((ref) {
  final all = ref.watch(consultationHistoryProvider).value ?? const [];
  return all.where((c) => c.status == ConsultationStatus.requested).toList()
    ..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
});

/// Accepts or declines a request, then refreshes the lists.
class RequestActions {
  RequestActions(this._ref);

  final Ref _ref;

  Future<Consultation> accept(String id) async {
    final session = await _ref.read(consultationRepositoryProvider).accept(id);
    _ref.invalidate(consultationHistoryProvider);
    return session;
  }

  Future<void> decline(String id) async {
    await _ref.read(consultationRepositoryProvider).reject(id);
    _ref.invalidate(consultationHistoryProvider);
  }

  Future<void> setOnline(bool online) async {
    await _ref.read(deskRepositoryProvider).setOnline(online);
    _ref.invalidate(deskProfileProvider);
  }
}

final requestActionsProvider = Provider((ref) => RequestActions(ref));

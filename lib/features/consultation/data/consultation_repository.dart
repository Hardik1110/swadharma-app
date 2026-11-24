import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/chat_message.dart';
import '../domain/consultation.dart';

/// Consumers use `/sessions`; astrologers use `/astrologer/sessions`.
final consultationRepositoryProvider = Provider((ref) {
  final astrologer = ref.watch(authProvider.select((u) => u.value?.isAstrologer ?? false));
  return ConsultationRepository(
    ref.watch(apiClientProvider),
    base: astrologer ? '/astrologer/sessions' : '/sessions',
  );
});

class ConsultationRepository {
  ConsultationRepository(this._api, {this.base = '/sessions'});

  final ApiClient _api;

  /// Collection path for this role.
  final String base;

  /// Consumer: ask an astrologer for a consultation.
  Future<Consultation> start(String astrologerId, ConsultationType type) async =>
      Consultation.fromJson(await _api.post<Map<String, dynamic>>(
          '/sessions', {'astrologerId': astrologerId, 'type': type.name}));

  Future<Consultation> get(String id) async =>
      Consultation.fromJson(await _api.get<Map<String, dynamic>>('$base/$id'));

  Future<List<Consultation>> history() async {
    final list = await _api.get<List<dynamic>>(base);
    return list.map((e) => Consultation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ChatMessage>> messages(String id) async {
    final list = await _api.get<List<dynamic>>('$base/$id/messages');
    return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// REST fallback used when the socket is down.
  Future<ChatMessage> sendMessage(String id, String text, String clientId) async =>
      ChatMessage.fromJson(await _api.post<Map<String, dynamic>>(
          '$base/$id/messages', {'text': text, 'clientId': clientId}));

  Future<Consultation> cancel(String id) async =>
      Consultation.fromJson(await _api.post<Map<String, dynamic>>('/sessions/$id/cancel'));

  Future<Consultation> end(String id, {String reason = 'user_ended'}) async =>
      Consultation.fromJson(
          await _api.post<Map<String, dynamic>>('$base/$id/end', {'reason': reason}));

  /// Astrologer: accept or decline a request.
  Future<Consultation> accept(String id) async => Consultation.fromJson(
      await _api.post<Map<String, dynamic>>('$base/$id/accept'));

  Future<Consultation> reject(String id) async => Consultation.fromJson(
      await _api.post<Map<String, dynamic>>('$base/$id/reject'));

  Future<Consultation> review(String id, int rating, String comment) async =>
      Consultation.fromJson(await _api.post<Map<String, dynamic>>(
          '/sessions/$id/review', {'rating': rating, 'comment': comment}));
}

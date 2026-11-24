import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/desk.dart';

final deskRepositoryProvider =
    Provider((ref) => DeskRepository(ref.watch(apiClientProvider)));

class DeskRepository {
  DeskRepository(this._api);

  final ApiClient _api;

  Future<DeskProfile> me() async =>
      DeskProfile.fromJson(await _api.get<Map<String, dynamic>>('/astrologer/me'));

  /// Throws [AppException] with code `session_active` during a consultation.
  Future<void> setOnline(bool online) async => _api.put<Map<String, dynamic>>(
      '/astrologer/status', {'status': online ? 'online' : 'offline'});
}

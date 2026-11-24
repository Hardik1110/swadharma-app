import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/astrologer.dart';

final astrologerRepositoryProvider =
    Provider((ref) => AstrologerRepository(ref.watch(apiClientProvider)));

class AstrologerRepository {
  AstrologerRepository(this._api);

  final ApiClient _api;

  Future<List<Astrologer>> list(AstrologerFilter filter) async {
    final json = await _api.get<List<dynamic>>('/astrologers', query: filter.toQuery());
    return json.map((e) => Astrologer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Astrologer> get(String id) async =>
      Astrologer.fromJson(await _api.get<Map<String, dynamic>>('/astrologers/$id'));

  Future<AppConfig> config() async =>
      AppConfig.fromJson(await _api.get<Map<String, dynamic>>('/config'));
}

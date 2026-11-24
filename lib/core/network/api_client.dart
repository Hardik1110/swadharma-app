import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/server_settings.dart';
import '../errors/app_exception.dart';
import '../storage/auth_token_provider.dart';

/// Called when the backend rejects our token; set up by the auth layer.
final unauthorizedHandlerProvider =
    Provider<void Function()>((ref) => () {});

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ref.watch(serverUrlProvider),
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    contentType: 'application/json',
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = ref.read(authTokenProvider);
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    },
    onError: (e, handler) {
      final isAuthCall = e.requestOptions.path.startsWith('/auth/');
      if (e.response?.statusCode == 401 && !isAuthCall) {
        ref.read(unauthorizedHandlerProvider)();
      }
      handler.next(e);
    },
  ));
  return ApiClient(dio);
});

/// Thin wrapper over Dio that converts every failure into [AppException].
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  /// The server this client talks to.
  String get baseUrl => _dio.options.baseUrl;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _run(() => _dio.get<T>(path, queryParameters: query));

  Future<T> post<T>(String path, [Object? body]) =>
      _run(() => _dio.post<T>(path, data: body ?? const {}));

  Future<T> put<T>(String path, Object? body) =>
      _run(() => _dio.put<T>(path, data: body));

  Future<T> _run<T>(Future<Response<T>> Function() request) async {
    try {
      final res = await request();
      return res.data as T;
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}

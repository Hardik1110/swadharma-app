import 'package:dio/dio.dart';

/// Every failure that reaches the UI is an [AppException] with a
/// human-readable [message].
class AppException implements Exception {
  const AppException(this.message, {this.code, this.statusCode});

  final String message;

  /// Machine-readable code from the backend, e.g. `astrologer_busy`.
  final String? code;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => code == 'network';

  factory AppException.from(Object error) {
    if (error is AppException) return error;
    if (error is DioException) return AppException.fromDio(error);
    return const AppException('Something went wrong. Please try again.');
  }

  factory AppException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        final base = e.requestOptions.baseUrl;
        return AppException(
          base.isEmpty
              ? 'Can\'t reach the server. Check your internet connection.'
              : 'Can\'t reach the server at $base. Check that it is running and '
                  'that this device is on the same network.',
          code: 'network',
        );
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        final err = data is Map ? data['error'] : null;
        if (err is Map) {
          return AppException(
            err['message'] as String? ?? 'Request failed',
            code: err['code'] as String?,
            statusCode: e.response?.statusCode,
          );
        }
        final status = e.response?.statusCode;
        if (status == 404) {
          // Our API always answers with a JSON error body, so a bare 404
          // means the request reached some other server.
          return AppException(
            'Can\'t find the Swadharma server at ${e.requestOptions.baseUrl}. '
            'Make sure it is running and the address is correct.',
            code: 'wrong_server',
            statusCode: 404,
          );
        }
        return AppException('Server error ($status)', statusCode: status);
      case DioExceptionType.cancel:
        return const AppException('Request cancelled', code: 'cancelled');
      default:
        return const AppException('Something went wrong. Please try again.');
    }
  }

  @override
  String toString() => message;
}

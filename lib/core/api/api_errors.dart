import 'package:dio/dio.dart';

/// Converts any exception into a short, human-readable message.
String friendlyError(Object e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server is taking too long to respond. Try again.';
      case DioExceptionType.connectionError:
        return 'Cannot reach server. Check your internet connection.';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final body = e.response?.data;
        // Try to extract server error message
        if (body is Map && body['error'] != null) {
          return body['error'].toString();
        }
        return switch (status) {
          400 => 'Invalid request.',
          401 => 'Session expired. Please log in again.',
          403 => 'Access denied.',
          404 => 'Not found.',
          429 => 'Too many requests. Please wait.',
          500 => 'Server error. Try again later.',
          502 || 503 => 'Server is starting up. Try again in a moment.',
          _ => 'Server error ($status).',
        };
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      default:
        return 'Network error. Try again.';
    }
  }
  // Strip noisy prefixes
  final msg = e.toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('DioException [bad_response]: ', '')
      .replaceFirst('DioException [connection_error]: ', '');
  if (msg.length > 120) return '${msg.substring(0, 120)}…';
  return msg;
}

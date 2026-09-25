import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../providers/storage_providers.dart';
import 'auth_events.dart';
import 'offline_cache.dart';

class DioClient {
  Dio create({
    required String baseUrl,
    FlutterSecureStorage? storage,
    AuthEventBus? authEvents,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    if (storage != null) {
      dio.interceptors.add(_AuthInterceptor(storage, authEvents));
    }

    // After auth (so the token is on the request), before logging.
    dio.interceptors.add(OfflineCacheInterceptor());
    dio.interceptors.add(
      PrettyDioLogger(requestBody: true, responseBody: true, compact: true),
    );
    return dio;
  }
}

/// Attaches the bearer token and turns a rejected token into a global logout.
///
/// The 401 handling deliberately SKIPS `/auth/` endpoints: login answers bad
/// credentials with 401, and treating that as "session expired" would wipe
/// state and bounce the user mid-login instead of showing "Invalid username or
/// password".
class _AuthInterceptor extends Interceptor {
  const _AuthInterceptor(this._storage, this._authEvents);

  final FlutterSecureStorage _storage;
  final AuthEventBus? _authEvents;

  /// Requests that legitimately answer 401 as *validation*, not expiry.
  static const _authPaths = '/auth/';

  /// Background/telemetry calls that must NEVER sign the technician out.
  ///
  /// FCM registration fires right after login and is not user-visible; if it
  /// fails the app still works perfectly, so treating its 401 as an expired
  /// session would boot a technician holding a perfectly valid token.
  static const _nonCriticalPaths = <String>['/fcm-token'];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: tokenKey);
    if (token != null) {
      options.headers['authorization'] = token;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;

    // /auth/session is the one auth path that MUST still trigger logout: its
    // whole job is to report that the stored token is dead.
    final isSessionCheck = path.contains('/auth/session');
    final isAuthCall = path.contains(_authPaths) && !isSessionCheck;
    final isNonCritical = _nonCriticalPaths.any(path.contains);
    final isRejectedToken = status == 401 || status == 403;

    if (isRejectedToken && !isAuthCall && !isNonCritical) {
      // Clear the dead token immediately so no in-flight retry re-sends it and
      // a cold start cannot restore a session the server already rejected.
      await _storage.delete(key: tokenKey);
      await _storage.delete(key: userDataKey);
      _authEvents?.sessionExpired(_messageFor(err));
    }

    handler.next(err);
  }

  String _messageFor(DioException err) {
    final data = err.response?.data;
    if (data is Map && data['message'] is String) {
      final msg = data['message'] as String;
      if (msg.trim().isNotEmpty) return msg;
    }
    return 'Your session has expired. Please log in again.';
  }
}

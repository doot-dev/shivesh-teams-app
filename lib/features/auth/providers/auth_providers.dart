import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/session_reset.dart';
import '../../../core/providers/storage_providers.dart';
import '../../../core/providers/tech_api_provider.dart';
import '../data/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(dioProvider));
});

/// Where the session restore has got to on cold start.
///
/// The splash screen blocks on this: routing before the stored token has been
/// read would bounce a perfectly signed-in technician to /login for the frame
/// or two it takes secure storage to answer.
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.token,
    this.name,
    this.userName,
    this.employeeId,
    this.phone,
    this.status = AuthStatus.unknown,
    this.isLoading = false,
    this.error,
    this.sessionMessage,
  });

  final String? token;
  final String? name;
  final String? userName;
  final String? employeeId;
  final String? phone;
  final AuthStatus status;
  final bool isLoading;
  final String? error;

  /// Set when a 30-day session was ended by the server rather than by the user,
  /// so the login screen can explain why they are suddenly back here.
  final String? sessionMessage;

  bool get isLoggedIn => token != null && status == AuthStatus.authenticated;
  bool get isRestoring => status == AuthStatus.unknown;

  AuthState copyWith({
    String? token,
    String? name,
    String? userName,
    String? employeeId,
    String? phone,
    AuthStatus? status,
    bool? isLoading,
    String? error,
    String? sessionMessage,
    bool clearError = false,
    bool clearSessionMessage = false,
  }) {
    return AuthState(
      token: token ?? this.token,
      name: name ?? this.name,
      userName: userName ?? this.userName,
      employeeId: employeeId ?? this.employeeId,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      sessionMessage:
          clearSessionMessage ? null : (sessionMessage ?? this.sessionMessage),
    );
  }
}

/// Owns the technician's session.
///
/// 30-DAY LOGIN: the backend signs the JWT with a 30-day expiry, and the token
/// is persisted in flutter_secure_storage. [_restoreSession] reloads it on every
/// cold start and only revalidates against `/auth/session`, so the technician is
/// asked for credentials again only when the token actually stops working —
/// never just because the app was closed.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // A server-side rejection anywhere in the app ends the session here.
    final bus = ref.read(authEventBusProvider);
    final sub = bus.sessionExpiredStream.listen(_onSessionExpired);
    ref.onDispose(sub.cancel);

    Future.microtask(_restoreSession);
    return const AuthState();
  }

  AuthService get _service => ref.read(authServiceProvider);

  Future<void> _onSessionExpired(String message) async {
    // The interceptor has already wiped storage; mirror that into state.
    state = AuthState(
      status: AuthStatus.unauthenticated,
      sessionMessage: message,
    );
    // Storage is not the only place the old session lives — the cached orders,
    // cube tests and profile must go too, or the next technician to sign in on
    // this phone would see them. Same reasoning as [logout].
    resetSessionData(ref);
  }

  /// Restore a persisted session, then confirm it is still accepted.
  ///
  /// Shows the stored identity optimistically so the app can render immediately,
  /// and only downgrades to unauthenticated if the server actively rejects the
  /// token. A network failure deliberately does NOT log the technician out —
  /// they work on sites with poor signal, and a dead cell tower is not an
  /// expired session.
  Future<void> _restoreSession() async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: tokenKey);
    final raw = await storage.read(key: userDataKey);

    if (token == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    Map<String, dynamic> stored = const {};
    if (raw != null) {
      try {
        stored = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        stored = const {};
      }
    }

    state = AuthState(
      token: token,
      name: stored['name'] as String?,
      userName: stored['userName'] as String?,
      employeeId: stored['employeeId'] as String?,
      phone: stored['phone'] as String?,
      status: AuthStatus.authenticated,
    );

    try {
      final res = await _service.session();
      final data = res['data'] as Map<String, dynamic>?;
      if (data != null) {
        await _persistUser(data);
        state = state.copyWith(
          name: data['name'] as String?,
          userName: data['userName'] as String?,
          employeeId: data['employeeId'] as String?,
          phone: data['phone'] as String?,
        );
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        // Handled by the interceptor -> _onSessionExpired. Nothing to do.
        return;
      }
      // Offline or server hiccup: keep the stored session.
    } catch (_) {
      // Same reasoning — never sign a technician out over a transport error.
    }
  }

  Future<void> _persistUser(Map<String, dynamic> data) async {
    final storage = ref.read(secureStorageProvider);
    await storage.write(
      key: userDataKey,
      value: jsonEncode({
        'name': data['name'],
        'userName': data['userName'],
        'employeeId': data['employeeId'],
        'phone': data['phone'],
      }),
    );
  }

  /// Username + password login. On success the 30-day token is persisted.
  Future<bool> login(String userName, String password) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSessionMessage: true,
    );
    try {
      final res = await _service.login(userName, password);
      if (res['success'] == true) {
        await _applyLogin(res['data'] as Map<String, dynamic>);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        error: res['message'] as String? ?? 'Login failed',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  Future<void> _applyLogin(Map<String, dynamic> data) async {
    // Belt and braces: a session that ended WITHOUT a clean logout (crash,
    // revoked token, app killed) leaves the previous technician's data cached.
    // Wipe it before this session's screens can read it.
    resetSessionData(ref);

    final token = data['token'] as String;
    final storage = ref.read(secureStorageProvider);

    await storage.write(key: tokenKey, value: token);
    await _persistUser(data);

    state = AuthState(
      token: token,
      name: data['name'] as String?,
      userName: data['userName'] as String?,
      employeeId: data['employeeId'] as String?,
      phone: data['phone'] as String?,
      status: AuthStatus.authenticated,
    );

    // Register for push AFTER the token is stored — the interceptor reads it
    // from secure storage, so registering earlier sends an unauthenticated call.
    unawaited(_initPush());
  }

  /// Start push and register this device. Never allowed to fail a login: a
  /// technician with no notifications can still work the whole app.
  Future<void> _initPush() async {
    try {
      await ref.read(notificationServiceProvider).initialize();
    } catch (_) {
      // Non-fatal — retried on the next login / cold start.
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _service.changePassword(oldPassword, newPassword);
      state = state.copyWith(isLoading: false);
      if (res['success'] == true) return true;
      state = state.copyWith(
        error: res['message'] as String? ?? 'Could not change password',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  // ─── Legacy OTP flow — for technicians without credentials ─────────────────

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _service.sendOtp(phone);
      state = state.copyWith(isLoading: false, phone: phone);
      return res['success'] == true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _service.verifyOtp(phone, otp);
      if (res['success'] == true) {
        await _applyLogin(res['data'] as Map<String, dynamic>);
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        error: res['message'] as String? ?? 'Verification failed',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    }
  }

  Future<void> logout() async {
    // Release the push slot BEFORE clearing the token: the unregister call is
    // authenticated, so wiping storage first would make it 401 and leave this
    // device occupying one of the technician's 5 slots (and still receiving
    // notifications for orders they no longer handle).
    try {
      await ref.read(notificationServiceProvider).unregister();
    } catch (_) {
      // Best effort — never block a logout on it.
    }

    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: tokenKey);
    await storage.delete(key: userDataKey);
    state = const AuthState(status: AuthStatus.unauthenticated);

    // Clearing the token is NOT enough. Every orders/cube-test/profile provider
    // is a plain (non-autoDispose) provider living in the root ProviderScope,
    // so without this the next technician to sign in on this phone would see
    // the previous one's cached data. Reset AFTER the state change so the
    // router has already redirected to /login and nothing refetches with a
    // dead token.
    resetSessionData(ref);
  }

  void clearSessionMessage() {
    state = state.copyWith(clearSessionMessage: true);
  }

  String _extractError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'Could not reach the server. Check your connection.';
      }
      return e.message ?? 'Network error';
    }
    return e.toString();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

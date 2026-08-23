import 'package:dio/dio.dart';

/// Field-technician auth endpoints.
///
/// The live flow is username + password: [login] returns a JWT that the backend
/// signs with a 30-day expiry, which is what keeps a technician signed in for
/// 30 days. The OTP pair is kept only for installs whose technicians have not
/// been given credentials yet.
class AuthService {
  const AuthService(this._dio);
  final Dio _dio;

  static const _base = '/api/v1/mobile/tech/auth';

  /// Primary login. Returns `{success, message, data:{token, name, ...}}`.
  Future<Map<String, dynamic>> login(String userName, String password) async {
    final res = await _dio.post(
      '$_base/login',
      data: {'userName': userName, 'password': password},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Revalidate a stored token on cold start.
  ///
  /// Cheap by design — the splash screen uses this to tell "my 30-day session is
  /// still good" apart from "the token was revoked", without waiting on an order
  /// fetch that could fail for unrelated network reasons.
  Future<Map<String, dynamic>> session() async {
    final res = await _dio.get('$_base/session');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    final res = await _dio.post(
      '$_base/change-password',
      data: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Legacy OTP step 1 — only for technicians without credentials.
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final res = await _dio.post('$_base/send-otp', data: {'phone': phone});
    return res.data as Map<String, dynamic>;
  }

  /// Legacy OTP step 2 — only for technicians without credentials.
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final res = await _dio.post(
      '$_base/verify-otp',
      data: {'phone': phone, 'otp': otp},
    );
    return res.data as Map<String, dynamic>;
  }
}

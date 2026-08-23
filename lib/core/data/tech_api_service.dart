import 'package:dio/dio.dart';

import '../../features/cube_test/data/models/cube_test_model.dart';
import '../../features/notifications/data/models/notification_model.dart';
import '../../features/orders/data/models/order_models.dart';
import '../../features/profile/data/models/technician_profile.dart';

/// Every authenticated call the field-technician app makes.
///
/// All order paths take the ORDER CODE (ORD-2025-0001), not the database id —
/// the backend resolves orders by `orderId` and additionally scopes each query
/// to the orders this technician is assigned to, so a wrong id returns 404
/// rather than someone else's data.
class TechApiService {
  const TechApiService(this._dio);
  final Dio _dio;

  static const _base = '/api/v1/mobile/tech';

  Future<TechnicianProfile> getProfile() async {
    final res = await _dio.get('$_base/profile');
    return TechnicianProfile.fromJson(
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  // ─── Orders ────────────────────────────────────────────────────────────────

  /// Orders assigned to this technician. [type] is `active` or `past`.
  Future<List<FieldOrder>> getOrders({String type = 'active'}) async {
    final res = await _dio.get(
      '$_base/orders',
      queryParameters: {'type': type},
    );
    final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => FieldOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FieldOrder> getOrder(String orderId) async {
    final res = await _dio.get('$_base/orders/$orderId');
    return FieldOrder.fromJson(
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// Move an order along its delivery track.
  ///
  /// [deliveryStatus] must be a backend enum value — use
  /// `DeliveryStatus.apiValue`, not the Dart enum name.
  Future<void> updateStatus(String orderId, String deliveryStatus) async {
    await _dio.put(
      '$_base/orders/$orderId/status',
      data: {'deliveryStatus': deliveryStatus},
    );
  }

  Future<List<Comment>> getComments(String orderId) async {
    final res = await _dio.get('$_base/orders/$orderId/comments');
    final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addComment(String orderId, String message) async {
    await _dio.post(
      '$_base/orders/$orderId/comments',
      data: {'message': message},
    );
  }

  // ─── Notifications ─────────────────────────────────────────────────────────

  Future<List<AppNotification>> getNotifications({String type = 'all'}) async {
    final res = await _dio.get(
      '$_base/notifications',
      queryParameters: {'type': type},
    );
    final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _dio.put('$_base/notifications/$notificationId/read');
  }

  // ─── TM details ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createTm(
    String orderId, {
    required String truckNo,
    required String qty,
    required String batchStartTime,
    required String batchEndTime,
    required String challanNo,
  }) async {
    final res = await _dio.post('$_base/orders/$orderId/tm', data: {
      'truckNo': truckNo,
      'qty': qty,
      'batchStartTime': batchStartTime,
      'batchEndTime': batchEndTime,
      'challanNo': challanNo,
    });
    return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  /// Update a TM. Only non-null fields are sent, matching the backend's
  /// partial-update semantics.
  Future<void> updateTm(
    String orderId,
    String tmId, {
    String? truckNo,
    String? qty,
    String? batchStartTime,
    String? batchEndTime,
    String? challanNo,
    String? status,
  }) async {
    await _dio.put('$_base/orders/$orderId/tm/$tmId', data: {
      'truckNo': ?truckNo,
      'qty': ?qty,
      'batchStartTime': ?batchStartTime,
      'batchEndTime': ?batchEndTime,
      'challanNo': ?challanNo,
      'status': ?status,
    });
  }

  Future<void> deleteTm(String orderId, String tmId) async {
    await _dio.delete('$_base/orders/$orderId/tm/$tmId');
  }

  // ─── Cube testing reports ──────────────────────────────────────────────────

  Future<List<CubeTest>> getCubeTests(String orderId) async {
    final res = await _dio.get('$_base/orders/$orderId/cube-test');
    final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => CubeTest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Log a cube test, optionally attaching the result sheet in the same request.
  ///
  /// Sent as multipart/form-data because of the file: the backend's multer
  /// middleware reads the attachment from the `file` field, and the scalar
  /// fields must ride along as form fields rather than JSON.
  ///
  /// [customDate] is REQUIRED when [period] is `CubeTestPeriod.custom` and must
  /// not be in the future — the server rejects both cases with a 400.
  Future<CubeTest> createCubeTest(
    String orderId, {
    required DateTime castingDate,
    required String quantity,
    required CubeTestPeriod period,
    DateTime? customDate,
    String? filePath,
    String? fileName,
  }) async {
    final form = FormData.fromMap({
      'castingDate': castingDate.toIso8601String(),
      'quantity': quantity,
      'period': period.apiValue,
      if (period == CubeTestPeriod.custom && customDate != null)
        'customDate': customDate.toIso8601String(),
      if (filePath != null)
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final res = await _dio.post(
      '$_base/orders/$orderId/cube-test',
      data: form,
    );
    return CubeTest.fromJson(
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteCubeTest(String orderId, String cubeTestId) async {
    await _dio.delete('$_base/orders/$orderId/cube-test/$cubeTestId');
  }

  /// Attach or replace the result sheet on an existing cube test.
  Future<void> uploadCubeTestFile(
    String orderId,
    String cubeTestId, {
    required String filePath,
    String? fileName,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    await _dio.put(
      '$_base/orders/$orderId/cube-test/$cubeTestId',
      data: form,
    );
  }
}

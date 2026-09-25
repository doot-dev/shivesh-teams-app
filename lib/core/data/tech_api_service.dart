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
  ///
  /// [query] is free text matched server-side against the order code, project
  /// name, client company, product and grade. [dateFrom]/[dateTo] filter by the
  /// delivery date and MUST be ISO `yyyy-MM-dd` — the backend silently ignores
  /// any other format rather than erroring, so a wrong format looks like "the
  /// filter did nothing".
  ///
  /// Blank/empty values are omitted entirely so an empty search box behaves
  /// exactly like no filter at all.
  Future<List<FieldOrder>> getOrders({
    String type = 'active',
    String? query,
    String? dateFrom,
    String? dateTo,
  }) async {
    final q = query?.trim() ?? '';
    final res = await _dio.get(
      '$_base/orders',
      queryParameters: {
        'type': type,
        if (q.isNotEmpty) 'q': q,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      },
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

  /// Move the order along: one of [fieldStatuses] (DISPATCHED, DELAYED,
  /// REACHED, COMPLETED). The server checks the step is allowed.
  Future<void> updateStatus(String orderId, String status) async {
    await _dio.put('$_base/orders/$orderId/status', data: {'status': status});
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

  // ─── Push registration ─────────────────────────────────────────────────────

  /// Register this device for push. The backend keeps at most 5 devices per
  /// technician and evicts the oldest, so re-registering is always safe.
  Future<void> registerFcmToken(String token, String platform) async {
    await _dio.put(
      '$_base/fcm-token',
      data: {'token': token, 'platform': platform},
    );
  }

  /// Drop this device on logout so the next technician to sign in on a shared
  /// site tablet does not inherit the previous one's notifications.
  Future<void> unregisterFcmToken(String token) async {
    await _dio.delete('$_base/fcm-token', data: {'token': token});
  }

  // ─── TM details ────────────────────────────────────────────────────────────

  /// Log a TM, optionally attaching the challan photo in the same request.
  ///
  /// Always sent as multipart/form-data — the backend's multer middleware reads
  /// the photo from the `challan` field, and mixing a JSON body with a file is
  /// not possible, so the scalar fields ride along as form fields.
  ///
  /// This works on CLOSED orders too: the server records `createdAt`, so a late
  /// challan is stamped with when it was really submitted.
  Future<Map<String, dynamic>> createTm(
    String orderId, {
    required String truckNo,
    required String qty,
    required String batchStartTime,
    required String batchEndTime,
    required String challanNo,
    String? challanFilePath,
    String? challanFileName,
    String? dispatchTime,
    String? arrivalTime,
  }) async {
    final form = FormData.fromMap({
      'dispatchTime': ?dispatchTime,
      'arrivalTime': ?arrivalTime,
      'truckNo': truckNo,
      'qty': qty,
      'batchStartTime': batchStartTime,
      'batchEndTime': batchEndTime,
      'challanNo': challanNo,
      if (challanFilePath != null)
        'challan': await MultipartFile.fromFile(
          challanFilePath,
          filename: challanFileName,
        ),
    });

    final res = await _dio.post('$_base/orders/$orderId/tm', data: form);
    return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  /// Update a TM. Only non-null fields are sent, matching the backend's
  /// partial-update semantics.
  ///
  /// Pass [challanFilePath] to attach or replace the challan photo — that
  /// switches the request to multipart, which the same endpoint accepts.
  Future<void> updateTm(
    String orderId,
    String tmId, {
    String? truckNo,
    String? qty,
    String? batchStartTime,
    String? batchEndTime,
    String? challanNo,
    String? status,
    String? challanFilePath,
    String? challanFileName,
  }) async {
    final fields = <String, dynamic>{
      'truckNo': ?truckNo,
      'qty': ?qty,
      'batchStartTime': ?batchStartTime,
      'batchEndTime': ?batchEndTime,
      'challanNo': ?challanNo,
      'status': ?status,
    };

    if (challanFilePath == null) {
      await _dio.put('$_base/orders/$orderId/tm/$tmId', data: fields);
      return;
    }

    final form = FormData.fromMap({
      ...fields,
      'challan': await MultipartFile.fromFile(
        challanFilePath,
        filename: challanFileName,
      ),
    });
    await _dio.put('$_base/orders/$orderId/tm/$tmId', data: form);
  }

  /// W32: the technician marks one truck as reached site.
  Future<void> markTmReached(String orderId, String tmId) async {
    await _dio.put('$_base/orders/$orderId/tm/$tmId/reached');
  }

  Future<void> deleteTm(String orderId, String tmId) async {
    await _dio.delete('$_base/orders/$orderId/tm/$tmId');
  }

  // ─── Cube testing reports ──────────────────────────────────────────────────

  /// Every cube test across ALL orders assigned to this technician.
  ///
  /// Backs the "Cube Tests" tab. [status] is `due` (test date reached) or
  /// `upcoming`; [dateFrom]/[dateTo] filter the CASTING date and must be ISO
  /// `yyyy-MM-dd` — the backend ignores any other format rather than erroring.
  /// Blank values are omitted so an empty search behaves like no filter.
  Future<List<CubeTestEntry>> getAllCubeTests({
    String? query,
    String? dateFrom,
    String? dateTo,
    String? status,
  }) async {
    final q = query?.trim() ?? '';
    final res = await _dio.get(
      '$_base/cube-tests',
      queryParameters: {
        if (q.isNotEmpty) 'q': q,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => CubeTestEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CubeTest>> getCubeTests(String orderId) async {
    final res = await _dio.get('$_base/orders/$orderId/cube-test');
    final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((e) => CubeTest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Log a cube test, optionally attaching result sheets in the same request.
  ///
  /// Sent as multipart/form-data because of the files: the backend's multer
  /// middleware reads them from the repeated `files` field (up to 10 per
  /// request), and the scalar fields ride along as form fields.
  ///
  /// [customDate] is REQUIRED when [period] is `CubeTestPeriod.custom` and must
  /// not be in the future — the server rejects both cases with a 400.
  Future<CubeTest> createCubeTest(
    String orderId, {
    required DateTime castingDate,
    required String quantity,
    required CubeTestPeriod period,
    DateTime? customDate,
    List<String> filePaths = const [],
  }) async {
    final form = FormData.fromMap({
      'castingDate': castingDate.toIso8601String(),
      'quantity': quantity,
      'period': period.apiValue,
      if (period == CubeTestPeriod.custom && customDate != null)
        'customDate': customDate.toIso8601String(),
    });
    await _addFiles(form, filePaths);

    final res = await _dio.post('$_base/orders/$orderId/cube-test', data: form);
    return CubeTest.fromJson(
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// Edit a cube test. Only non-null fields are sent; every path in
  /// [filePaths] is ADDED as a new attachment — nothing is replaced.
  Future<CubeTest> updateCubeTest(
    String orderId,
    String cubeTestId, {
    DateTime? castingDate,
    String? quantity,
    CubeTestPeriod? period,
    DateTime? customDate,
    List<String> filePaths = const [],
  }) async {
    final form = FormData.fromMap({
      'castingDate': ?castingDate?.toIso8601String(),
      'quantity': ?quantity,
      'period': ?period?.apiValue,
      'customDate': ?customDate?.toIso8601String(),
    });
    await _addFiles(form, filePaths);

    final res = await _dio.put(
      '$_base/orders/$orderId/cube-test/$cubeTestId',
      data: form,
    );
    return CubeTest.fromJson(
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// Each path as one repeated `files` part. The filename is the path's
  /// basename, which also sets the content type the server checks.
  Future<void> _addFiles(FormData form, List<String> paths) async {
    for (final p in paths) {
      form.files.add(MapEntry('files', await MultipartFile.fromFile(p)));
    }
  }

  /// Remove one attachment; returns the test with what is left.
  Future<CubeTest> deleteCubeTestAttachment(
    String orderId,
    String cubeTestId,
    String attachmentId,
  ) async {
    final res = await _dio.delete(
      '$_base/orders/$orderId/cube-test/$cubeTestId/attachments/$attachmentId',
    );
    return CubeTest.fromJson(
      (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteCubeTest(String orderId, String cubeTestId) async {
    await _dio.delete('$_base/orders/$orderId/cube-test/$cubeTestId');
  }
}

import 'package:dio/dio.dart';

import '../../features/notifications/data/models/notification_model.dart';
import '../../features/orders/data/models/order_models.dart';
import '../../features/profile/data/models/technician_profile.dart';

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

  Future<void> deleteTm(String orderId, String tmId) async {
    await _dio.delete('$_base/orders/$orderId/tm/$tmId');
  }
}

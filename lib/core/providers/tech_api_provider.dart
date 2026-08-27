import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tech_api_service.dart';
import '../services/notification_service.dart';
import 'dio_provider.dart';

final techApiProvider = Provider<TechApiService>((ref) {
  return TechApiService(ref.read(dioProvider));
});

/// Push notifications for this technician.
///
/// Deliberately NOT auto-disposed: the tap stream must outlive any single page
/// so a notification opened from a cold start still routes once the app is up.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(ref.read(techApiProvider));
  ref.onDispose(service.dispose);
  return service;
});

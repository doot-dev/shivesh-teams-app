import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/tech_api_provider.dart';
import '../data/models/notification_model.dart';

class _NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() {
    return ref.read(techApiProvider).getNotifications(type: 'general');
  }

  Future<void> markRead(String id) async {
    await ref.read(techApiProvider).markNotificationRead(id);
    ref.invalidateSelf();
  }
}

class _RemindersNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() {
    return ref.read(techApiProvider).getNotifications(type: 'reminder');
  }

  Future<void> markRead(String id) async {
    await ref.read(techApiProvider).markNotificationRead(id);
    ref.invalidateSelf();
  }
}

final notificationsProvider =
    AsyncNotifierProvider<_NotificationsNotifier, List<AppNotification>>(
  _NotificationsNotifier.new,
);

final remindersProvider =
    AsyncNotifierProvider<_RemindersNotifier, List<AppNotification>>(
  _RemindersNotifier.new,
);

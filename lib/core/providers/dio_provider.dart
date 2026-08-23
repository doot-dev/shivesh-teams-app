import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/auth_events.dart';
import '../network/dio_client.dart';
import 'storage_providers.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://31.97.206.154:3001',
);

/// Carries "token rejected" from the Dio interceptor to the auth layer.
final authEventBusProvider = Provider<AuthEventBus>((ref) {
  final bus = AuthEventBus();
  ref.onDispose(bus.dispose);
  return bus;
});

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);
  return DioClient().create(
    baseUrl: _baseUrl,
    storage: storage,
    authEvents: ref.read(authEventBusProvider),
  );
});

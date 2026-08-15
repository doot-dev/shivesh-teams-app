import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tech_api_service.dart';
import 'dio_provider.dart';

final techApiProvider = Provider<TechApiService>((ref) {
  return TechApiService(ref.read(dioProvider));
});

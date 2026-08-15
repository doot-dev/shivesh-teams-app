import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/tech_api_provider.dart';
import '../data/models/technician_profile.dart';

final technicianProfileProvider = FutureProvider<TechnicianProfile>((ref) {
  return ref.read(techApiProvider).getProfile();
});

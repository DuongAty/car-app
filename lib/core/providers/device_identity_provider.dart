import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_identity_service.dart';
import 'local_storage_provider.dart';

/// Override this in tests to avoid touching shared_preferences/platform channels.
final deviceIdentityServiceProvider = Provider<DeviceIdentityService>(
  (ref) => DeviceIdentityService(ref.watch(localStorageServiceProvider)),
);

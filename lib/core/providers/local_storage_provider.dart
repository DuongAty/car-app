import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_local_storage_service.dart';
import '../services/local_storage_service.dart';

/// Override this in tests to avoid touching the platform plugin.
final localStorageServiceProvider = Provider<LocalStorageService>(
  (ref) => DeviceLocalStorageService(),
);

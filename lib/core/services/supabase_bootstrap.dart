import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

Future<void>? _initialization;

/// Kicks off Supabase client initialization once and returns a cached future.
///
/// Called at startup WITHOUT awaiting, so it never blocks the first frame —
/// same shape as `ensureMusicSdkInitialized`. The license repository awaits
/// this same cached future before its first RPC call.
Future<void> ensureSupabaseInitialized() {
  return _initialization ??= _initialize();
}

Future<void> _initialize() async {
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  } catch (error, stackTrace) {
    developer.log(
      'Supabase initialization failed',
      name: 'viet_ktv.supabase',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

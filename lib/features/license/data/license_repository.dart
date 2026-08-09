import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_bootstrap.dart';
import 'models/license_rpc_result.dart';

/// Talks to the license backend. Controllers depend on this interface rather
/// than the Supabase client directly, so tests can substitute a fake and
/// never touch the network (same split as `LocalStorageService`).
abstract interface class LicenseRepository {
  /// Called when the user submits a key from the input screen.
  Future<LicenseRpcResult> requestActivation({
    required String keyCode,
    required String userName,
    required String deviceId,
    required String deviceLabel,
    required String androidVersion,
  });

  /// Called on startup (for a previously-saved key) and while polling during
  /// [LicenseRpcResult.pending].
  Future<LicenseRpcResult> checkLicense({
    required String keyCode,
    required String deviceId,
  });
}

class SupabaseLicenseRepository implements LicenseRepository {
  const SupabaseLicenseRepository();

  @override
  Future<LicenseRpcResult> requestActivation({
    required String keyCode,
    required String userName,
    required String deviceId,
    required String deviceLabel,
    required String androidVersion,
  }) async {
    await ensureSupabaseInitialized();
    final client = Supabase.instance.client;
    dynamic raw;
    try {
      raw = await client.rpc(
        'request_activation',
        params: {
          'p_key': keyCode,
          'p_user_name': userName,
          'p_device_id': deviceId,
          'p_device_label': deviceLabel,
          'p_android_version': androidVersion,
        },
      );
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') rethrow;
      // Allows this app release to keep activating keys until the database
      // migration has been applied. The name is persisted immediately after
      // that migration is live.
      raw = await client.rpc(
        'request_activation',
        params: {
          'p_key': keyCode,
          'p_device_id': deviceId,
          'p_device_label': deviceLabel,
          'p_android_version': androidVersion,
        },
      );
    }
    return LicenseRpcResult.parse(raw as String);
  }

  @override
  Future<LicenseRpcResult> checkLicense({
    required String keyCode,
    required String deviceId,
  }) async {
    await ensureSupabaseInitialized();
    final raw = await Supabase.instance.client.rpc(
      'check_license',
      params: {'p_key': keyCode, 'p_device_id': deviceId},
    );
    return LicenseRpcResult.parse(raw as String);
  }
}

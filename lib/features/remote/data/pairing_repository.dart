import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_bootstrap.dart';
import 'models/pairing_result.dart';

/// Names of the pairing RPCs and their parameters, in one place.
///
/// The migration is written in a separate repo, so if a parameter ends up
/// named differently there this is the only file that has to change.
abstract final class PairingRpc {
  static const String createCode = 'create_pairing_code';
  static const String reset = 'reset_pairing';

  static const String paramCarDeviceId = 'p_car_device_id';
  static const String paramCarLabel = 'p_car_label';

  static const String fieldPairingId = 'pairing_id';
  static const String fieldCode = 'code';
  static const String fieldExpiresAt = 'expires_at';
}

/// Pairing half of the remote backend. `claim_pairing_code` is deliberately
/// absent: only the phone calls it.
abstract interface class PairingRepository {
  /// Mints (or re-mints) the six-digit code for this head unit. Calling it
  /// again issues a new code for the same `pairing_id`.
  Future<PairingCodeResult> createCode({
    required String carDeviceId,
    required String carLabel,
  });

  /// Rotates the channel secret, cutting off whatever phone was paired.
  Future<PairingResetResult> resetPairing(String carDeviceId);
}

class SupabasePairingRepository implements PairingRepository {
  const SupabasePairingRepository();

  static const String _logName = 'viet_ktv.remote.pairing';

  @override
  Future<PairingCodeResult> createCode({
    required String carDeviceId,
    required String carLabel,
  }) async {
    final Object? raw;
    try {
      await ensureSupabaseInitialized();
      raw = await Supabase.instance.client.rpc(
        PairingRpc.createCode,
        params: {
          PairingRpc.paramCarDeviceId: carDeviceId,
          PairingRpc.paramCarLabel: carLabel,
        },
      );
    } on PostgrestException catch (error) {
      developer.log('create_pairing_code lỗi', name: _logName, error: error);
      return PairingCodeFailure(PairingFailureKind.backend, error.message);
    } catch (error) {
      developer.log(
        'create_pairing_code lỗi mạng',
        name: _logName,
        error: error,
      );
      return PairingCodeFailure(PairingFailureKind.network, '$error');
    }

    final payload = decodePairingPayload(raw);
    final pairingId = payload?[PairingRpc.fieldPairingId];
    final code = payload?[PairingRpc.fieldCode];
    final expiresAt = DateTime.tryParse(
      payload?[PairingRpc.fieldExpiresAt] as String? ?? '',
    );
    if (payload == null ||
        pairingId is! String ||
        pairingId.isEmpty ||
        code is! String ||
        code.isEmpty ||
        expiresAt == null) {
      return const PairingCodeFailure(
        PairingFailureKind.malformed,
        'Thiếu pairing_id/code/expires_at',
      );
    }
    return PairingCodeIssued(
      pairingId: pairingId,
      code: code,
      expiresAt: expiresAt.toLocal(),
    );
  }

  @override
  Future<PairingResetResult> resetPairing(String carDeviceId) async {
    final Object? raw;
    try {
      await ensureSupabaseInitialized();
      raw = await Supabase.instance.client.rpc(
        PairingRpc.reset,
        params: {PairingRpc.paramCarDeviceId: carDeviceId},
      );
    } on PostgrestException catch (error) {
      developer.log('reset_pairing lỗi', name: _logName, error: error);
      return PairingResetFailure(PairingFailureKind.backend, error.message);
    } catch (error) {
      developer.log('reset_pairing lỗi mạng', name: _logName, error: error);
      return PairingResetFailure(PairingFailureKind.network, '$error');
    }

    final pairingId = decodePairingPayload(raw)?[PairingRpc.fieldPairingId];
    if (pairingId is! String || pairingId.isEmpty) {
      return const PairingResetFailure(
        PairingFailureKind.malformed,
        'Thiếu pairing_id',
      );
    }
    return PairingResetDone(pairingId);
  }
}

import 'package:viet_ktv/features/remote/data/models/pairing_result.dart';
import 'package:viet_ktv/features/remote/data/pairing_repository.dart';

/// Pairing backend without a network. [codeResult]/[resetResult] can be
/// swapped mid-test to drive the failure branches.
class FakePairingRepository implements PairingRepository {
  FakePairingRepository({PairingCodeResult? codeResult, this.resetResult})
    : codeResult =
          codeResult ??
          PairingCodeIssued(
            pairingId: 'pairing-secret',
            code: '123456',
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          );

  PairingCodeResult codeResult;
  PairingResetResult? resetResult;

  int createCount = 0;
  int resetCount = 0;
  String? lastCarLabel;

  @override
  Future<PairingCodeResult> createCode({
    required String carDeviceId,
    required String carLabel,
  }) async {
    createCount++;
    lastCarLabel = carLabel;
    return codeResult;
  }

  @override
  Future<PairingResetResult> resetPairing(String carDeviceId) async {
    resetCount++;
    return resetResult ?? const PairingResetDone('pairing-secret-2');
  }
}

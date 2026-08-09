import 'package:viet_ktv/features/license/data/license_repository.dart';
import 'package:viet_ktv/features/license/data/models/license_rpc_result.dart';

/// Fake backend for the license gate. [checkResult]/[requestResult] are
/// returned as-is (or thrown, if set to an [Exception]) from each call, so
/// tests can drive the gate through every screen without touching the
/// network.
class FakeLicenseRepository implements LicenseRepository {
  FakeLicenseRepository({
    LicenseRpcResult? checkResult,
    LicenseRpcResult? requestResult,
  }) : checkResult = checkResult ?? LicenseRpcResult.activeSelf,
       requestResult = requestResult ?? LicenseRpcResult.pending;

  LicenseRpcResult checkResult;
  LicenseRpcResult requestResult;
  Object? checkError;
  Object? requestError;

  String? lastCheckedKey;
  String? lastRequestedKey;
  String? lastRequestedUserName;
  int checkCallCount = 0;

  @override
  Future<LicenseRpcResult> checkLicense({
    required String keyCode,
    required String deviceId,
  }) async {
    lastCheckedKey = keyCode;
    checkCallCount++;
    final error = checkError;
    if (error != null) {
      throw error;
    }
    return checkResult;
  }

  @override
  Future<LicenseRpcResult> requestActivation({
    required String keyCode,
    required String userName,
    required String deviceId,
    required String deviceLabel,
    required String androidVersion,
  }) async {
    lastRequestedKey = keyCode;
    lastRequestedUserName = userName;
    final error = requestError;
    if (error != null) {
      throw error;
    }
    return requestResult;
  }
}

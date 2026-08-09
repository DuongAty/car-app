import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/device_identity_provider.dart';
import '../../../../core/providers/local_storage_provider.dart';
import '../../../../core/services/device_identity_service.dart';
import '../../data/license_local_store.dart';
import '../../data/license_repository.dart';
import '../../data/models/license_rpc_result.dart';
import 'license_gate_state.dart';

final licenseRepositoryProvider = Provider<LicenseRepository>(
  (ref) => const SupabaseLicenseRepository(),
);

final licenseLocalStoreProvider = Provider<LicenseLocalStore>(
  (ref) => LicenseLocalStore(ref.watch(localStorageServiceProvider)),
);

final licenseControllerProvider =
    StateNotifierProvider<LicenseController, LicenseGateState>(
      (ref) => LicenseController(
        deviceIdentity: ref.watch(deviceIdentityServiceProvider),
        repository: ref.watch(licenseRepositoryProvider),
        localStore: ref.watch(licenseLocalStoreProvider),
      ),
    );

/// Poll interval while a request is awaiting admin approval. Frequent enough
/// to feel instant to someone standing at the box, cheap enough to run for
/// minutes without hammering the backend.
const _pollInterval = Duration(seconds: 4);

class LicenseController extends StateNotifier<LicenseGateState> {
  LicenseController({
    required this.deviceIdentity,
    required this.repository,
    required this.localStore,
  }) : super(const LicenseGateState.checking()) {
    unawaited(_init());
  }

  final DeviceIdentityService deviceIdentity;
  final LicenseRepository repository;
  final LicenseLocalStore localStore;

  Timer? _pollTimer;
  String? _deviceId;

  Future<void> _init() async {
    _deviceId = await deviceIdentity.getOrCreateDeviceId();
    final savedKey = await localStore.readKeyCode();
    if (!mounted) {
      return;
    }
    if (savedKey == null) {
      state = state.copyWith(status: LicenseGateStatus.needsKey);
      return;
    }
    await _verify(savedKey);
  }

  /// Re-checks [keyCode] against the server; used on startup for a saved key
  /// and on every poll tick while pending.
  Future<void> _verify(String keyCode) async {
    try {
      final deviceId = _deviceId ??= await deviceIdentity.getOrCreateDeviceId();
      final result = await repository.checkLicense(
        keyCode: keyCode,
        deviceId: deviceId,
      );
      await _applyResult(keyCode, result);
    } catch (_) {
      if (!mounted) {
        return;
      }
      final cached = await localStore.readLastGoodStatus();
      if (!mounted) {
        return;
      }
      if (cached == LicenseCachedStatus.active) {
        // Already verified active before and just offline right now — let
        // the box keep working; a box mid-session should not lock out over
        // a Wi-Fi blip.
        state = state.copyWith(
          status: LicenseGateStatus.active,
          activeKeyCode: keyCode,
        );
        return;
      }
      state = state.copyWith(
        status: LicenseGateStatus.offlineRetry,
        activeKeyCode: keyCode,
      );
    }
  }

  Future<void> _applyResult(String keyCode, LicenseRpcResult result) async {
    if (!mounted) {
      return;
    }
    switch (result) {
      case LicenseRpcResult.activeSelf:
        await localStore.save(
          keyCode: keyCode,
          status: LicenseCachedStatus.active,
        );
        _cancelPoll();
        if (!mounted) return;
        state = state.copyWith(
          status: LicenseGateStatus.active,
          activeKeyCode: keyCode,
        );
      case LicenseRpcResult.pending:
        await localStore.save(
          keyCode: keyCode,
          status: LicenseCachedStatus.pending,
        );
        if (!mounted) return;
        state = state.copyWith(
          status: LicenseGateStatus.pending,
          activeKeyCode: keyCode,
        );
        _schedulePoll(keyCode);
      case LicenseRpcResult.locked:
        await localStore.save(
          keyCode: keyCode,
          status: LicenseCachedStatus.locked,
        );
        _cancelPoll();
        if (!mounted) return;
        state = state.copyWith(
          status: LicenseGateStatus.locked,
          activeKeyCode: keyCode,
        );
      case LicenseRpcResult.expired:
        await localStore.save(
          keyCode: keyCode,
          status: LicenseCachedStatus.expired,
        );
        _cancelPoll();
        if (!mounted) return;
        state = state.copyWith(
          status: LicenseGateStatus.expired,
          activeKeyCode: keyCode,
        );
      case LicenseRpcResult.activeOther:
        await localStore.clear();
        _cancelPoll();
        if (!mounted) return;
        state = const LicenseGateState(
          status: LicenseGateStatus.needsKey,
          inputError: LicenseInputError.activeOther,
        );
      case LicenseRpcResult.notFound:
        await localStore.clear();
        _cancelPoll();
        if (!mounted) return;
        state = const LicenseGateState(
          status: LicenseGateStatus.needsKey,
          inputError: LicenseInputError.notFound,
        );
      case LicenseRpcResult.available:
        // Status flipped back to hoat_dong server-side (e.g. admin removed
        // the device binding) — this device must ask again.
        await localStore.clear();
        _cancelPoll();
        if (!mounted) return;
        state = const LicenseGateState(status: LicenseGateStatus.needsKey);
    }
  }

  void _schedulePoll(String keyCode) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _verify(keyCode));
  }

  void _cancelPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void updateEnteredKey(String value) {
    state = state.copyWith(
      enteredKey: value,
      inputError: LicenseInputError.none,
    );
  }

  void updateEnteredUserName(String value) {
    state = state.copyWith(
      enteredUserName: value,
      inputError: LicenseInputError.none,
    );
  }

  Future<void> submitKey() async {
    final keyCode = state.enteredKey.trim().toUpperCase();
    final userName = state.enteredUserName.trim();
    if (keyCode.isEmpty || state.isSubmitting) {
      return;
    }
    if (userName.isEmpty) {
      state = state.copyWith(inputError: LicenseInputError.missingUserName);
      return;
    }
    state = state.copyWith(
      isSubmitting: true,
      inputError: LicenseInputError.none,
    );
    try {
      // Submitting can race _init()'s device id lookup (e.g. a user typing
      // fast on first launch) — never send a request without one.
      final deviceId = _deviceId ??= await deviceIdentity.getOrCreateDeviceId();
      final info = await deviceIdentity.getDeviceInfo();
      final result = await repository.requestActivation(
        keyCode: keyCode,
        userName: userName,
        deviceId: deviceId,
        deviceLabel: info.label,
        androidVersion: info.androidVersion,
      );
      if (!mounted) return;
      state = state.copyWith(isSubmitting: false);
      await _applyResult(keyCode, result);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isSubmitting: false,
        inputError: LicenseInputError.network,
      );
    }
  }

  /// Manual re-check from the locked/offline screens (no background polling
  /// there — the user taps "Kiểm tra lại" when they believe something
  /// changed).
  Future<void> retry() async {
    final keyCode = state.activeKeyCode;
    if (keyCode == null) {
      await _init();
      return;
    }
    await _verify(keyCode);
  }

  /// Leaves the locked/pending/offline screen and forgets the bound key so
  /// the user can type a different one.
  Future<void> changeKey() async {
    _cancelPoll();
    await localStore.clear();
    if (!mounted) return;
    state = const LicenseGateState(status: LicenseGateStatus.needsKey);
  }

  @override
  void dispose() {
    _cancelPoll();
    super.dispose();
  }
}

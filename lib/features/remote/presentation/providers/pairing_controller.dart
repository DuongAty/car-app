import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/device_identity_provider.dart';
import '../../data/models/pairing_result.dart';
import 'remote_session_provider.dart';

/// Scoped to the pairing page: the one-second countdown must die with the
/// screen, not tick for the rest of the session.
final pairingControllerProvider =
    StateNotifierProvider.autoDispose<PairingController, PairingState>((ref) {
      final controller = PairingController(ref);
      ref.onDispose(controller.stopCountdown);
      return controller;
    });

class PairingState {
  const PairingState({
    this.isBusy = false,
    this.code,
    this.remaining = Duration.zero,
    this.pairingId,
    this.phoneOnline = false,
    this.error,
  });

  /// An RPC is in flight (issuing a code or resetting).
  final bool isBusy;

  /// The six digits currently on screen, null when there is none to show.
  final String? code;

  /// Time left before [code] expires. Drives the countdown ring.
  final Duration remaining;

  /// Non-null once this box has ever been paired.
  final String? pairingId;

  /// A phone is present on the realtime channel right now.
  final bool phoneOnline;

  final PairingFailureKind? error;

  bool get isPaired => pairingId != null;

  bool get hasActiveCode => code != null && remaining > Duration.zero;

  bool get isExpired => code != null && remaining <= Duration.zero;

  PairingState copyWith({
    bool? isBusy,
    String? code,
    bool clearCode = false,
    Duration? remaining,
    String? pairingId,
    bool? phoneOnline,
    PairingFailureKind? error,
    bool clearError = false,
  }) {
    return PairingState(
      isBusy: isBusy ?? this.isBusy,
      code: clearCode ? null : (code ?? this.code),
      remaining: remaining ?? this.remaining,
      pairingId: pairingId ?? this.pairingId,
      phoneOnline: phoneOnline ?? this.phoneOnline,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PairingController extends StateNotifier<PairingState> {
  PairingController(this._ref) : super(const PairingState()) {
    _ref.listen<String?>(remotePairingIdProvider, (_, pairingId) {
      if (mounted) {
        state = state.copyWith(pairingId: pairingId);
      }
    }, fireImmediately: true);

    _presence = _ref.read(remoteChannelProvider).phoneOnline.listen((online) {
      if (mounted) {
        state = state.copyWith(phoneOnline: online);
      }
    });

    unawaited(requestCode());
  }

  final Ref _ref;
  StreamSubscription<bool>? _presence;
  Timer? _countdown;
  DateTime? _expiresAt;

  /// Asks the backend for a fresh six-digit code. Calling it again while one
  /// is still valid simply replaces it — the `pairing_id` does not change.
  Future<void> requestCode() async {
    if (state.isBusy) {
      return;
    }
    state = state.copyWith(isBusy: true, clearError: true);

    final identity = _ref.read(deviceIdentityServiceProvider);
    final deviceId = await identity.getOrCreateDeviceId();
    final info = await identity.getDeviceInfo();
    final result = await _ref
        .read(pairingRepositoryProvider)
        .createCode(carDeviceId: deviceId, carLabel: info.label);
    if (!mounted) {
      return;
    }

    switch (result) {
      case PairingCodeIssued(:final pairingId, :final code, :final expiresAt):
        await _ref.read(remotePairingIdProvider.notifier).save(pairingId);
        if (!mounted) {
          return;
        }
        _expiresAt = expiresAt;
        state = state.copyWith(
          isBusy: false,
          code: code,
          pairingId: pairingId,
          remaining: _remaining(),
          clearError: true,
        );
        _startCountdown();
      case PairingCodeFailure(:final kind):
        stopCountdown();
        state = state.copyWith(isBusy: false, clearCode: true, error: kind);
    }
  }

  /// Rotates the secret. The previously paired phone loses access at once:
  /// its channel simply has nobody on the other end any more.
  Future<void> disconnectPhone() async {
    if (state.isBusy) {
      return;
    }
    state = state.copyWith(isBusy: true, clearError: true);

    final deviceId = await _ref
        .read(deviceIdentityServiceProvider)
        .getOrCreateDeviceId();
    final result = await _ref
        .read(pairingRepositoryProvider)
        .resetPairing(deviceId);
    if (!mounted) {
      return;
    }

    switch (result) {
      case PairingResetDone(:final pairingId):
        await _ref.read(remotePairingIdProvider.notifier).save(pairingId);
        if (!mounted) {
          return;
        }
        stopCountdown();
        state = state.copyWith(
          isBusy: false,
          clearCode: true,
          remaining: Duration.zero,
          pairingId: pairingId,
          phoneOnline: false,
          clearError: true,
        );
      case PairingResetFailure(:final kind):
        state = state.copyWith(isBusy: false, error: kind);
    }
  }

  void _startCountdown() {
    _countdown?.cancel();
    // One second is the coarsest tick a "còn 4:59" readout can use. Only the
    // countdown leaf watches it, so the rest of the page does not rebuild.
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final remaining = _remaining();
      state = state.copyWith(remaining: remaining);
      if (remaining <= Duration.zero) {
        stopCountdown();
      }
    });
  }

  Duration _remaining() {
    final expiresAt = _expiresAt;
    if (expiresAt == null) {
      return Duration.zero;
    }
    final left = expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void stopCountdown() {
    _countdown?.cancel();
    _countdown = null;
  }

  @override
  void dispose() {
    stopCountdown();
    unawaited(_presence?.cancel());
    super.dispose();
  }
}

/// The exact string encoded into the pairing QR.
///
/// **The phone app parses this, so the shape is part of the contract:**
/// `wektv://pair?code=<six digits>`. Changing the scheme, host, or parameter
/// name breaks every already-released phone build.
String pairingQrPayload(String code) => 'wektv://pair?code=$code';

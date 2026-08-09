/// Screen the license gate should currently show.
enum LicenseGateStatus {
  /// Reading the saved key (if any) and verifying it with the server.
  checking,

  /// No key saved (or the saved one was rejected) — show the input keyboard.
  needsKey,

  /// A valid, unclaimed key was submitted; waiting for the admin to approve
  /// it. Polls the server periodically.
  pending,

  /// The bound key was locked by the admin.
  locked,

  /// The bound key's `expires_at` has passed.
  expired,

  /// A key is saved locally but the server can't be reached and there is no
  /// usable cached status to fall back on.
  offlineRetry,

  /// Verified: this device may enter the app.
  active,
}

/// Why the last submit/check was rejected, shown as inline copy on the input
/// screen. `none` means no error message should be shown. A locked key gets
/// its own full [LicenseGateStatus.locked] screen instead of an inline error.
enum LicenseInputError { none, missingUserName, notFound, activeOther, network }

class LicenseGateState {
  const LicenseGateState({
    required this.status,
    this.enteredKey = '',
    this.enteredUserName = '',
    this.activeKeyCode,
    this.inputError = LicenseInputError.none,
    this.isSubmitting = false,
  });

  const LicenseGateState.checking() : this(status: LicenseGateStatus.checking);

  /// Current screen.
  final LicenseGateStatus status;

  /// Characters typed so far on the input keyboard (only meaningful while
  /// [status] is [LicenseGateStatus.needsKey]).
  final String enteredKey;

  /// Name supplied by the customer with the activation request. It is saved
  /// on the license record so the admin can find a key later.
  final String enteredUserName;

  /// The key this device is currently bound to / waiting on / locked on —
  /// shown back to the user on the pending/locked/offline screens.
  final String? activeKeyCode;

  /// Inline error to show on the input screen, if any.
  final LicenseInputError inputError;

  /// Whether a submit request is in flight (disables the submit key/shows a
  /// small spinner instead of blocking the whole screen).
  final bool isSubmitting;

  LicenseGateState copyWith({
    LicenseGateStatus? status,
    String? enteredKey,
    String? enteredUserName,
    Object? activeKeyCode = _unset,
    LicenseInputError? inputError,
    bool? isSubmitting,
  }) {
    return LicenseGateState(
      status: status ?? this.status,
      enteredKey: enteredKey ?? this.enteredKey,
      enteredUserName: enteredUserName ?? this.enteredUserName,
      activeKeyCode: identical(activeKeyCode, _unset)
          ? this.activeKeyCode
          : activeKeyCode as String?,
      inputError: inputError ?? this.inputError,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

const _unset = Object();

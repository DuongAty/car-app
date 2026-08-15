import 'dart:convert';

/// Why a pairing RPC did not produce a usable answer.
///
/// Kept coarse on purpose: the pairing screen only ever offers "thử lại", so
/// finer grades would be copy the user cannot act on differently.
enum PairingFailureKind {
  /// Could not reach the backend at all.
  network,

  /// The backend answered with an error (RPC missing, RLS, constraint).
  backend,

  /// The backend answered, but not with the shape this app understands.
  malformed,
}

/// Result of `create_pairing_code`.
sealed class PairingCodeResult {
  const PairingCodeResult();
}

class PairingCodeIssued extends PairingCodeResult {
  const PairingCodeIssued({
    required this.pairingId,
    required this.code,
    required this.expiresAt,
  });

  /// The channel secret. 32 random bytes from the backend — never shown on
  /// screen and never logged, unlike [code].
  final String pairingId;

  /// Six digits, valid for five minutes, single use.
  final String code;

  final DateTime expiresAt;
}

class PairingCodeFailure extends PairingCodeResult {
  const PairingCodeFailure(this.kind, this.detail);

  final PairingFailureKind kind;

  /// Diagnostic only — never rendered; the UI maps [kind] to localized copy.
  final String detail;
}

/// Result of `reset_pairing`.
sealed class PairingResetResult {
  const PairingResetResult();
}

class PairingResetDone extends PairingResetResult {
  const PairingResetDone(this.pairingId);

  /// The freshly minted secret. The old phone loses access the moment the car
  /// stops listening on the old channel — no separate revocation needed.
  final String pairingId;
}

class PairingResetFailure extends PairingResetResult {
  const PairingResetFailure(this.kind, this.detail);

  final PairingFailureKind kind;
  final String detail;
}

/// Normalizes what `Supabase.rpc` hands back.
///
/// The client returns a decoded `Map` for a `json`-returning function on some
/// versions and the raw JSON string on others, so both are accepted rather
/// than casting and hoping.
Map<String, dynamic>? decodePairingPayload(Object? raw) {
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      return null;
    }
  }
  return null;
}

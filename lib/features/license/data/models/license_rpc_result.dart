/// Mirrors the text codes returned by the Supabase RPCs
/// `request_activation` and `check_license` (see
/// `backend/supabase/schema.sql`).
enum LicenseRpcResult {
  /// No license row matches the entered key.
  notFound,

  /// Key status is `khoa` (locked).
  locked,

  /// Key status is `dang_kich_hoat` but `expires_at` has passed.
  expired,

  /// Key status is `dang_kich_hoat` and bound to this exact device.
  activeSelf,

  /// Key status is `dang_kich_hoat` but bound to a different device.
  activeOther,

  /// Key status is `hoat_dong` and this device now has a pending request.
  pending,

  /// Key status is `hoat_dong` and no request from this device is pending
  /// (only returned by `check_license`, never by `request_activation`).
  available;

  static LicenseRpcResult parse(String raw) => switch (raw) {
    'not_found' => LicenseRpcResult.notFound,
    'locked' => LicenseRpcResult.locked,
    'expired' => LicenseRpcResult.expired,
    'active_self' => LicenseRpcResult.activeSelf,
    'active_other' => LicenseRpcResult.activeOther,
    'pending' => LicenseRpcResult.pending,
    'available' => LicenseRpcResult.available,
    _ => throw ArgumentError('Unknown license RPC result: $raw'),
  };
}

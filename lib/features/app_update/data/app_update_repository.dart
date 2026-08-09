import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_bootstrap.dart';
import 'models/app_release.dart';

abstract interface class AppUpdateRepository {
  /// The newest active release, or null when nothing has been published.
  /// Throws if the backend cannot be reached — the controller turns that into
  /// a retryable error, which is different from "no release".
  Future<AppRelease?> latestRelease();
}

class SupabaseAppUpdateRepository implements AppUpdateRepository {
  const SupabaseAppUpdateRepository();

  @override
  Future<AppRelease?> latestRelease() async {
    await ensureSupabaseInitialized();
    final raw = await Supabase.instance.client.rpc('latest_release');
    return AppRelease.tryParse(raw);
  }
}

import '../../../l10n/app_localizations.dart';

String formatRelativeTime(AppLocalizations l10n, DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) {
    return l10n.historyJustNow;
  }
  if (diff.inMinutes < 60) {
    return l10n.historyMinutesAgo(diff.inMinutes);
  }
  if (diff.inHours < 24) {
    return l10n.historyHoursAgo(diff.inHours);
  }
  return l10n.historyDaysAgo(diff.inDays);
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/app_system_service.dart';
import '../../../../core/shared/widgets/app_top_nav.dart';
import '../../../../core/shared/widgets/glow_card.dart';
import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/shared/widgets/language_toggle.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../l10n/l10n.dart';
import '../../../../routes/app_router.dart';
import '../../../playback/presentation/widgets/app_control_bar.dart';
import '../../../settings/data/models/app_settings.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../../data/mock/source_selection_mock_data.dart';
import '../../data/models/music_source.dart';
import '../providers/source_selection_provider.dart';
import '../widgets/source_card_content.dart';

class SourceSelectionPage extends ConsumerStatefulWidget {
  const SourceSelectionPage({super.key});

  @override
  ConsumerState<SourceSelectionPage> createState() =>
      _SourceSelectionPageState();
}

class _SourceSelectionPageState extends ConsumerState<SourceSelectionPage> {
  // Grown to match the source list rather than fixed at a count, which went
  // stale the moment a source was removed. The nodes must outlive a rebuild,
  // so they are created once here and reused.
  final List<FocusNode> _sourceNodes = <FocusNode>[];

  List<FocusNode> _nodesFor(int count) {
    while (_sourceNodes.length < count) {
      _sourceNodes.add(FocusNode());
    }
    return _sourceNodes;
  }

  @override
  void dispose() {
    for (final node in _sourceNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _openSource(int index, MusicSource source) {
    ref.read(sourceSelectionProvider.notifier).selectSource(index, source);
    Navigator.of(context).pushNamed(AppRouter.songBrowser, arguments: source);
  }

  void _handleTopAction(SourceSelectionController controller, int index) {
    controller.selectTopAction(index);
    if (index == SourceSelectionMockData.settingsActionIndex) {
      Navigator.of(context).pushNamed(AppRouter.settings);
      return;
    }
    if (index == SourceSelectionMockData.connectPhoneActionIndex) {
      Navigator.of(context).pushNamed(
        AppRouter.settings,
        arguments: const SettingsRouteArguments(
          initialCategory: SettingsCategory.device,
        ),
      );
      return;
    }
    if (index == SourceSelectionMockData.exitActionIndex) {
      _showExitDialog();
    }
  }

  Future<void> _showExitDialog() async {
    final l10n = context.l10n;
    final action = await showDialog<_ExitAction>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panelStrong,
        title: Text(l10n.exitDialogTitle),
        content: Text(l10n.exitDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.cancel),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.restart),
            child: Text(l10n.restartApp),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.shutdown),
            child: Text(l10n.shutdownDevice),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.exit),
            child: Text(l10n.exitApp),
          ),
        ],
      ),
    );
    if (!mounted || action == null || action == _ExitAction.cancel) {
      return;
    }
    switch (action) {
      case _ExitAction.exit:
        SystemNavigator.pop();
      case _ExitAction.restart:
        try {
          await const AppSystemService().restartApp();
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.restartUnavailable)));
        }
      case _ExitAction.shutdown:
        try {
          await const AppSystemService().shutdownDevice();
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.shutdownUnavailable)));
        }
      case _ExitAction.cancel:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only the top-nav selection is rendered from this provider; watching the
    // whole state made every D-pad move between cards rebuild all three glass
    // cards (see onFocusChange below, which no longer writes unused state).
    final selectedTopActionIndex = ref.watch(
      sourceSelectionProvider.select((state) => state.selectedTopActionIndex),
    );
    final controller = ref.read(sourceSelectionProvider.notifier);
    final locale = ref.watch(appLocaleProvider);
    final particlesEnabled = ref.watch(
      settingsControllerProvider.select(
        (settings) => settings.particlesEnabled,
      ),
    );
    final localeController = ref.read(appLocaleProvider.notifier);
    final l10n = context.l10n;
    final sources = SourceSelectionMockData.localizedSources(l10n);

    return KaraokeShell(
      topBar: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 920;
          // Mirrors MainTopBar's structure (song_browser/main_top_bar.dart):
          // the nav is centred on the whole bar via a Stack, with the other
          // controls layered in a Row on top, so the nav's centre matches
          // screen centre regardless of what flanks it and never shifts
          // between the source picker and the browser page.
          return SizedBox(
            height: AppLayout.topNavItemHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    SizedBox(width: compact ? 12 : 28),
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: LanguageToggle(
                        isVietnamese: locale.languageCode == 'vi',
                        onToggle: localeController.toggle,
                      ),
                    ),
                  ],
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AppTopNav(
                    actions: SourceSelectionMockData.topActions(l10n),
                    selectedIndex: selectedTopActionIndex,
                    style: TopNavStyle.boxed,
                    onSelected: (index) => _handleTopAction(controller, index),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compactHeight = constraints.maxHeight < 560;
          final headlineGap = compactHeight ? 14.0 : 30.0;
          final cardsGap = compactHeight ? 18.0 : AppLayout.sourceCardsTopGap;

          return Column(
            children: [
              SizedBox(height: headlineGap),
              const _Headline(),
              SizedBox(height: cardsGap),
              Expanded(
                child: _ResponsiveSourceGrid(
                  sources: sources,
                  focusNodes: _nodesFor(sources.length),
                  particlesEnabled: particlesEnabled,
                  onOpenSource: _openSource,
                ),
              ),
            ],
          );
        },
      ),
      bottomBar: const AppControlBar(),
    );
  }
}

class _ResponsiveSourceGrid extends StatelessWidget {
  const _ResponsiveSourceGrid({
    required this.sources,
    required this.focusNodes,
    required this.particlesEnabled,
    required this.onOpenSource,
  });

  final List<MusicSource> sources;
  final List<FocusNode> focusNodes;
  final bool particlesEnabled;
  final void Function(int index, MusicSource source) onOpenSource;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final gap = constraints.maxWidth < 900 ? 18.0 : AppLayout.sourceRowGap;
        final availableWidth = constraints.maxWidth - gap * (columns - 1);
        final cardWidth = availableWidth / columns;
        final targetHeight = (constraints.maxHeight - gap).clamp(180.0, 560.0);
        final cardHeight = columns == 1
            ? (targetHeight * 0.82).clamp(180.0, 420.0)
            : targetHeight;
        final aspectRatio = cardWidth / cardHeight;

        // Never lay out more columns than there are sources. With three
        // columns and only two sources the grid filled the left two thirds
        // and left the right one empty. Card size still comes from the
        // responsive `columns` above, so trimming here centres the row
        // rather than stretching the cards to fill it.
        final filledColumns = columns > sources.length
            ? sources.length
            : columns;
        final rowWidth = cardWidth * filledColumns + gap * (filledColumns - 1);

        return Center(
          child: SizedBox(
            width: rowWidth,
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: filledColumns,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                childAspectRatio: aspectRatio,
              ),
              itemCount: sources.length,
              itemBuilder: (context, index) {
                final source = sources[index];
                return GlowCard(
                  accentColor: source.accentColor,
                  particleSeed: 5 + index * 9,
                  showParticles: particlesEnabled,
                  autofocus: index == 0,
                  focusNode: focusNodes[index],
                  onPressed: () => onOpenSource(index, source),
                  child: SourceCardContent(source: source),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

enum _ExitAction { exit, restart, shutdown, cancel }

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final display = textTheme.displaySmall;

    return Column(
      children: [
        Text(
          context.l10n.homeWelcome,
          style: display,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppLayout.sourceHeadlineGap),
        Text(
          context.l10n.homeSubtitle,
          style: textTheme.bodyMedium?.copyWith(fontSize: 26),
        ),
      ],
    );
  }
}

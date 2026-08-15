import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/glow_card.dart';
import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../l10n/l10n.dart';
import '../../../../routes/app_router.dart';
import '../../../navigation/presentation/widgets/main_nav_rail.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../../data/models/music_source.dart';
import '../../data/mock/source_selection_mock_data.dart';
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

  @override
  Widget build(BuildContext context) {
    // Nothing from sourceSelectionProvider is rendered here any more — the
    // brand mark and the destinations moved into MainNavRail, which watches
    // its own slices. Watching the whole state here made every D-pad move
    // between cards rebuild all three glass cards.
    final particlesEnabled = ref.watch(
      settingsControllerProvider.select(
        (settings) => settings.particlesEnabled,
      ),
    );
    final sources = SourceSelectionMockData.localizedSources(context.l10n);

    return KaraokeShell(
      navRail: const MainNavRail(selectedId: NavDestination.home),
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

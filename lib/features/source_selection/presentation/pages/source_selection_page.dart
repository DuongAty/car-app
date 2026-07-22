import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/volume_provider.dart';
import '../../../../core/shared/widgets/app_bottom_hint_bar.dart';
import '../../../../core/shared/widgets/app_top_nav.dart';
import '../../../../core/shared/widgets/brand_wordmark.dart';
import '../../../../core/shared/widgets/glow_card.dart';
import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/shared/widgets/language_toggle.dart';
import '../../../../core/shared/widgets/volume_indicator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../l10n/l10n.dart';
import '../../../../routes/app_router.dart';
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
  late final List<FocusNode> _sourceNodes;

  @override
  void initState() {
    super.initState();
    _sourceNodes = List.generate(3, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final node in _sourceNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _openSource(int index, MusicSource source) {
    ref.read(sourceSelectionProvider.notifier).selectSource(index);
    Navigator.of(context).pushNamed(AppRouter.songBrowser, arguments: source);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sourceSelectionProvider);
    final controller = ref.read(sourceSelectionProvider.notifier);
    final locale = ref.watch(appLocaleProvider);
    final localeController = ref.read(appLocaleProvider.notifier);
    final volume = ref.watch(volumeProvider);
    final l10n = context.l10n;
    final sources = SourceSelectionMockData.localizedSources(l10n);

    return KaraokeShell(
      showEdgeParticles: true,
      topBar: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: BrandWordmark(fontSize: 46),
          ),
          const Spacer(flex: 5),
          AppTopNav(
            actions: SourceSelectionMockData.topActions(l10n),
            selectedIndex: state.selectedTopActionIndex,
            style: TopNavStyle.boxed,
            onSelected: controller.selectTopAction,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: LanguageToggle(
              isVietnamese: locale.languageCode == 'vi',
              onToggle: localeController.toggle,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: AppLayout.sourceHeadlineTopSpace),
          const _Headline(),
          const SizedBox(height: AppLayout.sourceCardsTopGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < sources.length; index++) ...[
                if (index > 0) const SizedBox(width: AppLayout.sourceRowGap),
                SizedBox(
                  width: AppLayout.sourceCardWidth,
                  height:
                      AppLayout.sourceCardHeight +
                      AppLayout.sourceAccentBarGap +
                      AppLayout.sourceAccentBarHeight,
                  child: GlowCard(
                    accentColor: sources[index].accentColor,
                    particleSeed: 5 + index * 9,
                    autofocus: index == 0,
                    focusNode: _sourceNodes[index],
                    onFocusChange: (focused) {
                      if (focused) {
                        controller.selectSource(index);
                      }
                    },
                    onPressed: () => _openSource(index, sources[index]),
                    child: SourceCardContent(source: sources[index]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      bottomBar: AppBottomHintBar(
        leading: VolumeIndicator(
          level: volume.level,
          enabled: volume.isAvailable,
          onChanged: ref.read(volumeProvider.notifier).setLevel,
        ),
        items: SourceSelectionMockData.bottomHints(l10n),
        trailingItems: SourceSelectionMockData.trailingHints(l10n),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final display = textTheme.displaySmall;
    final brand = display?.copyWith(fontStyle: FontStyle.italic);

    return Column(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${context.l10n.homeWelcome} '),
              TextSpan(
                text: 'VIET',
                style: brand?.copyWith(color: AppColors.green),
              ),
              TextSpan(text: 'KTV', style: brand),
            ],
          ),
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

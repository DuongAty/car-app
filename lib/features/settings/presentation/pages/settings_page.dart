import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/shared/widgets/surface_scope.dart';
import '../../../favorites/presentation/providers/favorites_controller.dart';
import '../../../history/presentation/providers/history_controller.dart';
import '../../../playback/presentation/widgets/app_control_bar.dart';
import '../../../song_browser/data/mock/song_browser_mock_data.dart';
import '../../../song_browser/presentation/widgets/main_top_bar.dart';
import '../../data/models/app_settings.dart';
import '../providers/settings_controller.dart';
import '../widgets/settings_content_panel.dart';
import '../widgets/settings_preview_panel.dart';
import '../widgets/settings_sidebar.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.initialCategory});

  final SettingsCategory? initialCategory;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _initialCategoryApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialCategoryApplied || widget.initialCategory == null) {
      return;
    }
    _initialCategoryApplied = true;
    ref
        .read(settingsControllerProvider.notifier)
        .selectCategory(widget.initialCategory!);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final onClearFavorites = ref
        .read(favoritesControllerProvider.notifier)
        .clear;
    final onClearHistory = ref.read(historyControllerProvider.notifier).clear;

    return KaraokeShell(
      topBar: MainTopBar(selectedIndex: SongBrowserMockData.settingsTabIndex),
      // Each column below watches only the slice it needs via its own
      // Consumer. Dragging a slider changes the whole AppSettings, but with
      // this split only the content + preview rebuild per frame — the
      // sidebar (10 tiles) and the shell do not.
      body: LayoutBuilder(
        builder: (context, constraints) {
          // KaraokeShell guarantees this body an outer landscape canvas of
          // at least 1366x768, but subtracts its own horizontal padding
          // (AppLayout.shellHorizontalPaddingFor) first, so the width
          // actually reaching here floors around 1270, not 1366. That is
          // well clear of the sidebar/preview-visibility split below (was
          // `constraints.maxWidth < 1040` — always false, so that branch
          // and the `showPreview` guard were removed), but it is NOT clear
          // of this 1320 breakpoint: a device at the real 1366x768 minimum
          // lands here below 1320 and renders a 320-wide preview column;
          // only larger devices (e.g. 1920x1080) clear 1320 and get 430.
          // Keep this ternary live.
          final previewWidth = constraints.maxWidth >= 1320 ? 430.0 : 320.0;

          return ContentSlab(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _sidebarWidth,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final selectedCategory = ref.watch(
                        settingsControllerProvider.select(
                          (s) => s.selectedCategory,
                        ),
                      );
                      return SettingsSidebar(
                        selectedCategory: selectedCategory,
                        onSelected: controller.selectCategory,
                      );
                    },
                  ),
                ),
                const SurfaceDivider(axis: Axis.vertical),
                Expanded(
                  flex: 7,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final settings = ref.watch(settingsControllerProvider);
                      return SettingsContentPanel(
                        settings: settings,
                        controller: controller,
                        onClearFavorites: onClearFavorites,
                        onClearHistory: onClearHistory,
                      );
                    },
                  ),
                ),
                const SurfaceDivider(axis: Axis.vertical),
                SizedBox(
                  width: previewWidth,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final settings = ref.watch(settingsControllerProvider);
                      return SettingsPreviewPanel(settings: settings);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomBar: const AppControlBar(),
    );
  }
}

// The shell's body floor (~1270, see comment above) is always above the
// 1040 breakpoint that used to switch this to a narrower compact width, so
// the sidebar width is fixed.
const double _sidebarWidth = 330.0;

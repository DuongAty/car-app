import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Semantic icon tokens for the karaoke neon liquid-glass interface.
///
/// Keep feature code pointing at these names instead of a concrete icon pack,
/// so visual direction changes stay centralized.
abstract final class AppIcons {
  static const IconData search = Symbols.search_rounded;
  static const IconData categoryGrid = Symbols.apps_rounded;
  static const IconData queue = Symbols.queue_music_rounded;
  static const IconData playlist = Symbols.library_music_rounded;
  static const IconData selectedQueue = Symbols.format_list_bulleted_rounded;
  static const IconData settings = Symbols.settings_suggest_rounded;
  static const IconData power = Symbols.power_settings_new_rounded;
  static const IconData connectPhone = Symbols.qr_code_2_rounded;
  static const IconData language = Symbols.language_rounded;
  static const IconData history = Symbols.history_rounded;
  static const IconData home = Symbols.home_rounded;
  static const IconData deviceHub = Symbols.hub_rounded;
  static const IconData display = Symbols.desktop_windows_rounded;
  static const IconData palette = Symbols.palette_rounded;
  static const IconData videoSettings = Symbols.video_settings_rounded;
  static const IconData account = Symbols.person_rounded;
  static const IconData info = Symbols.info_rounded;
  static const IconData movie = Symbols.movie_rounded;
  static const IconData captions = Symbols.closed_caption_rounded;
  static const IconData timer = Symbols.timer_rounded;
  static const IconData highQuality = Symbols.high_quality_rounded;
  static const IconData cache = Symbols.cached_rounded;

  static const IconData favorite = Symbols.favorite_rounded;
  static const IconData favoriteOutline = Symbols.favorite_border_rounded;
  static const IconData add = Symbols.add_rounded;
  static const IconData close = Symbols.close_rounded;
  static const IconData clearAll = Symbols.delete_sweep_rounded;
  static const IconData back = Symbols.undo_rounded;
  static const IconData menu = Symbols.menu_rounded;
  static const IconData chevronRight = Symbols.chevron_right_rounded;
  static const IconData chevronUp = Symbols.keyboard_arrow_up_rounded;
  static const IconData chevronDown = Symbols.keyboard_arrow_down_rounded;
  static const IconData dragHandle = Symbols.drag_indicator_rounded;

  static const IconData play = Symbols.play_arrow_rounded;
  static const IconData pause = Symbols.pause_rounded;
  static const IconData previous = Symbols.skip_previous_rounded;
  static const IconData rewind = Symbols.fast_rewind_rounded;
  static const IconData fastForward = Symbols.fast_forward_rounded;
  static const IconData next = Symbols.skip_next_rounded;
  static const IconData repeat = Symbols.repeat_rounded;
  static const IconData repeatOne = Symbols.repeat_one_rounded;
  static const IconData shuffle = Symbols.shuffle_rounded;
  static const IconData fullscreen = Symbols.fullscreen_rounded;
  static const IconData fullscreenExit = Symbols.fullscreen_exit_rounded;

  /// Collapses/expands the left search column. Named for the panel that moves,
  /// which is the one on the left.
  static const IconData panelClose = Symbols.left_panel_close_rounded;
  static const IconData panelOpen = Symbols.left_panel_open_rounded;

  static const IconData warning = Symbols.error_outline_rounded;
  static const IconData fire = Symbols.local_fire_department_rounded;
  static const IconData backspace = Symbols.backspace_rounded;
  static const IconData microphone = Symbols.mic_none_rounded;
  static const IconData microphoneOff = Symbols.mic_off_rounded;
  static const IconData musicNote = Symbols.music_note_rounded;

  static const IconData volumeOff = Symbols.volume_off_rounded;
  static const IconData volumeDown = Symbols.volume_down_rounded;
  static const IconData volumeUp = Symbols.volume_up_rounded;

  static const IconData key = Symbols.vpn_key_rounded;
  static const IconData lock = Symbols.lock_rounded;
  static const IconData pending = Symbols.hourglass_top_rounded;
  static const IconData checkCircle = Symbols.check_circle_rounded;
  static const IconData refresh = Symbols.refresh_rounded;
  static const IconData wifiOff = Symbols.wifi_off_rounded;
}

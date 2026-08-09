import 'dart:convert';

enum SettingsCategory {
  device,
  audio,
  display,
  interface,
  video,
  language,
  songManagement,
  account,
  system,
  info,
}

enum VideoQuality { fourK, fullHd, hd, sd, auto }

class AppSettings {
  const AppSettings({
    this.selectedCategory = SettingsCategory.video,
    this.videoQuality = VideoQuality.hd,
    this.continuousPlayback = true,
    this.repeatAll = false,
    this.repeatOne = false,
    this.shuffle = false,
    this.bufferSeconds = 5,
    this.autoPlayMv = true,
    this.showCaptions = true,
    this.demoVideoEnabled = true,
    this.masterVolume = 0.72,
    this.musicVolume = 0.66,
    this.vocalBoost = true,
    this.lyricScale = 0.58,
    this.visualizerEnabled = false,
    this.glowLevel = 0.42,
    this.particlesEnabled = false,
    this.performanceDefaultsVersion = 2,
  });

  final SettingsCategory selectedCategory;
  final VideoQuality videoQuality;
  final bool continuousPlayback;
  final bool repeatAll;
  final bool repeatOne;
  final bool shuffle;
  final int bufferSeconds;
  final bool autoPlayMv;
  final bool showCaptions;
  final bool demoVideoEnabled;
  final double masterVolume;
  final double musicVolume;
  final bool vocalBoost;
  final double lyricScale;
  final bool visualizerEnabled;
  final double glowLevel;
  final bool particlesEnabled;
  final int performanceDefaultsVersion;

  AppSettings copyWith({
    SettingsCategory? selectedCategory,
    VideoQuality? videoQuality,
    bool? continuousPlayback,
    bool? repeatAll,
    bool? repeatOne,
    bool? shuffle,
    int? bufferSeconds,
    bool? autoPlayMv,
    bool? showCaptions,
    bool? demoVideoEnabled,
    double? masterVolume,
    double? musicVolume,
    bool? vocalBoost,
    double? lyricScale,
    bool? visualizerEnabled,
    double? glowLevel,
    bool? particlesEnabled,
    int? performanceDefaultsVersion,
  }) {
    return AppSettings(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      videoQuality: videoQuality ?? this.videoQuality,
      continuousPlayback: continuousPlayback ?? this.continuousPlayback,
      repeatAll: repeatAll ?? this.repeatAll,
      repeatOne: repeatOne ?? this.repeatOne,
      shuffle: shuffle ?? this.shuffle,
      bufferSeconds: bufferSeconds ?? this.bufferSeconds,
      autoPlayMv: autoPlayMv ?? this.autoPlayMv,
      showCaptions: showCaptions ?? this.showCaptions,
      demoVideoEnabled: demoVideoEnabled ?? this.demoVideoEnabled,
      masterVolume: masterVolume ?? this.masterVolume,
      musicVolume: musicVolume ?? this.musicVolume,
      vocalBoost: vocalBoost ?? this.vocalBoost,
      lyricScale: lyricScale ?? this.lyricScale,
      visualizerEnabled: visualizerEnabled ?? this.visualizerEnabled,
      glowLevel: glowLevel ?? this.glowLevel,
      particlesEnabled: particlesEnabled ?? this.particlesEnabled,
      performanceDefaultsVersion:
          performanceDefaultsVersion ?? this.performanceDefaultsVersion,
    );
  }

  Map<String, Object> toJson() => {
    'videoQuality': videoQuality.name,
    'continuousPlayback': continuousPlayback,
    'repeatAll': repeatAll,
    'repeatOne': repeatOne,
    'shuffle': shuffle,
    'bufferSeconds': bufferSeconds,
    'autoPlayMv': autoPlayMv,
    'showCaptions': showCaptions,
    'demoVideoEnabled': demoVideoEnabled,
    'masterVolume': masterVolume,
    'musicVolume': musicVolume,
    'vocalBoost': vocalBoost,
    'lyricScale': lyricScale,
    'visualizerEnabled': visualizerEnabled,
    'glowLevel': glowLevel,
    'particlesEnabled': particlesEnabled,
    'performanceDefaultsVersion': performanceDefaultsVersion,
  };

  String encode() => jsonEncode(toJson());

  static AppSettings decode(String? value) {
    if (value == null) {
      return const AppSettings();
    }
    try {
      final data = jsonDecode(value);
      if (data is! Map<String, dynamic>) {
        return const AppSettings();
      }
      final performanceDefaultsVersion =
          (data['performanceDefaultsVersion'] as num?)?.toInt() ?? 0;
      final shouldApplyBoxDefaults = performanceDefaultsVersion < 2;
      return AppSettings(
        videoQuality: VideoQuality.values.byName(
          data['videoQuality'] as String? ?? VideoQuality.hd.name,
        ),
        continuousPlayback: data['continuousPlayback'] as bool? ?? true,
        repeatAll: data['repeatAll'] as bool? ?? false,
        repeatOne: data['repeatOne'] as bool? ?? false,
        shuffle: data['shuffle'] as bool? ?? false,
        bufferSeconds: (data['bufferSeconds'] as num?)?.toInt() ?? 5,
        autoPlayMv: data['autoPlayMv'] as bool? ?? true,
        showCaptions: data['showCaptions'] as bool? ?? true,
        demoVideoEnabled: data['demoVideoEnabled'] as bool? ?? true,
        masterVolume: (data['masterVolume'] as num?)?.toDouble() ?? 0.72,
        musicVolume: (data['musicVolume'] as num?)?.toDouble() ?? 0.66,
        vocalBoost: data['vocalBoost'] as bool? ?? true,
        lyricScale: (data['lyricScale'] as num?)?.toDouble() ?? 0.58,
        visualizerEnabled: shouldApplyBoxDefaults
            ? false
            : data['visualizerEnabled'] as bool? ?? false,
        glowLevel: shouldApplyBoxDefaults
            ? 0.42
            : (data['glowLevel'] as num?)?.toDouble() ?? 0.42,
        particlesEnabled: shouldApplyBoxDefaults
            ? false
            : data['particlesEnabled'] as bool? ?? false,
        performanceDefaultsVersion: 2,
      );
    } on FormatException {
      return const AppSettings();
    } on ArgumentError {
      return const AppSettings();
    }
  }
}

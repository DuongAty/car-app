import 'package:flutter/material.dart';

class MusicSource {
  const MusicSource({
    required this.id,
    required this.subtitle,
    required this.accentColor,
    required this.logoStyle,
  });

  final String id;
  final String subtitle;
  final Color accentColor;
  final MusicSourceLogoStyle logoStyle;
}

enum MusicSourceLogoStyle { youtube, soundcloud, mixcloud }

class SongItem {
  const SongItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.thumbnailSeed,
    this.imageUrl,
    required this.badge,
  });

  final String id;
  final String title;
  final String subtitle;
  final String duration;
  final int thumbnailSeed;
  final String? imageUrl;
  final String? badge;
}

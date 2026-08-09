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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'duration': duration,
    'thumbnailSeed': thumbnailSeed,
    'imageUrl': imageUrl,
    'badge': badge,
  };

  factory SongItem.fromJson(Map<String, dynamic> json) => SongItem(
    id: json['id'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String,
    duration: json['duration'] as String,
    thumbnailSeed: json['thumbnailSeed'] as int,
    imageUrl: json['imageUrl'] as String?,
    badge: json['badge'] as String?,
  );
}

class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String url;
  final String path;
  final List<String> lyrics;
  final int duration;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.url,
    required this.path,
    required this.lyrics,
    required this.duration,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'url': url,
      'path': path,
      'lyrics': lyrics,
      'duration': duration,
    };
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      album: map['album'] ?? '',
      url: map['url'] ?? '',
      path: map['path'] ?? '',
      lyrics: List<String>.from(map['lyrics'] ?? []),
      duration: map['duration'] ?? 0,
    );
  }

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? url,
    String? path,
    List<String>? lyrics,
    int? duration,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      url: url ?? this.url,
      path: path ?? this.path,
      lyrics: lyrics ?? this.lyrics,
      duration: duration ?? this.duration,
    );
  }
}

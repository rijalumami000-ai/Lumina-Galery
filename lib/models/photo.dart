class PhotoEXIF {
  final String camera;
  final String lens;
  final String aperture;
  final String shutterSpeed;
  final String iso;
  final String focalLength;
  final String location;

  PhotoEXIF({
    required this.camera,
    required this.lens,
    required this.aperture,
    required this.shutterSpeed,
    required this.iso,
    required this.focalLength,
    required this.location,
  });

  factory PhotoEXIF.fromJson(Map<String, dynamic> json) {
    return PhotoEXIF(
      camera: json['camera'] ?? '',
      lens: json['lens'] ?? '',
      aperture: json['aperture'] ?? '',
      shutterSpeed: json['shutterSpeed'] ?? '',
      iso: json['iso'] ?? '',
      focalLength: json['focalLength'] ?? '',
      location: json['location'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'camera': camera,
      'lens': lens,
      'aperture': aperture,
      'shutterSpeed': shutterSpeed,
      'iso': iso,
      'focalLength': focalLength,
      'location': location,
    };
  }
}

class Photo {
  final String id;
  final String title;
  final String description;
  final String category;
  final String url;
  final String thumbnailUrl;
  final String author;
  final String authorAvatar;
  final String date;
  final PhotoEXIF exif;

  Photo({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.url,
    required this.thumbnailUrl,
    required this.author,
    required this.authorAvatar,
    required this.date,
    required this.exif,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      url: json['url'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      author: json['author'] ?? '',
      authorAvatar: json['authorAvatar'] ?? '',
      date: json['date'] ?? '',
      exif: PhotoEXIF.fromJson(json['exif'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'author': author,
      'authorAvatar': authorAvatar,
      'date': date,
      'exif': exif.toJson(),
    };
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CustomAlbum {
  final String id;
  final String name;
  final String description;
  final List<String> photoIds;
  final String createdAt;

  CustomAlbum({
    required this.id,
    required this.name,
    required this.description,
    required this.photoIds,
    required this.createdAt,
  });

  factory CustomAlbum.fromJson(Map<String, dynamic> json) {
    return CustomAlbum(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      photoIds: List<String>.from(json['photoIds'] ?? []),
      createdAt: json['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'photoIds': photoIds,
      'createdAt': createdAt,
    };
  }
}

class DatabaseHelper {
  static const String _favoritesKey = 'lumina_favorites';
  static const String _albumsKey = 'lumina_albums';

  // --- FAVORITES ---

  static Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  static Future<List<String>> toggleFavorite(String photoId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoritesKey) ?? [];
    
    if (favorites.contains(photoId)) {
      favorites.remove(photoId);
    } else {
      favorites.add(photoId);
    }
    
    await prefs.setStringList(_favoritesKey, favorites);
    return favorites;
  }

  static Future<bool> isFavorite(String photoId) async {
    final favorites = await getFavorites();
    return favorites.contains(photoId);
  }

  // --- ALBUMS ---

  static Future<List<CustomAlbum>> getAlbums() async {
    final prefs = await SharedPreferences.getInstance();
    final String? albumsJson = prefs.getString(_albumsKey);
    if (albumsJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(albumsJson);
      return decoded.map((item) => CustomAlbum.fromJson(item)).toList();
    } catch (e) {
      print('Error parsing albums: $e');
      return [];
    }
  }

  static Future<List<CustomAlbum>> createAlbum(String name, String description) async {
    final prefs = await SharedPreferences.getInstance();
    final albums = await getAlbums();

    final now = DateTime.now();
    final String formattedDate = "${_monthName(now.month)} ${now.day}, ${now.year}";

    final newAlbum = CustomAlbum(
      id: 'album-${now.millisecondsSinceEpoch}',
      name: name,
      description: description,
      photoIds: [],
      createdAt: formattedDate,
    );

    albums.add(newAlbum);
    await _saveAlbums(prefs, albums);
    return albums;
  }

  static Future<List<CustomAlbum>> addPhotoToAlbum(String albumId, String photoId) async {
    final prefs = await SharedPreferences.getInstance();
    final albums = await getAlbums();

    for (var album in albums) {
      if (album.id == albumId) {
        if (!album.photoIds.contains(photoId)) {
          album.photoIds.add(photoId);
        }
      }
    }

    await _saveAlbums(prefs, albums);
    return albums;
  }

  static Future<List<CustomAlbum>> removePhotoFromAlbum(String albumId, String photoId) async {
    final prefs = await SharedPreferences.getInstance();
    final albums = await getAlbums();

    for (var album in albums) {
      if (album.id == albumId) {
        album.photoIds.remove(photoId);
      }
    }

    await _saveAlbums(prefs, albums);
    return albums;
  }

  static Future<List<CustomAlbum>> deleteAlbum(String albumId) async {
    final prefs = await SharedPreferences.getInstance();
    var albums = await getAlbums();
    albums = albums.where((album) => album.id != albumId).toList();
    await _saveAlbums(prefs, albums);
    return albums;
  }

  static Future<void> _saveAlbums(SharedPreferences prefs, List<CustomAlbum> albums) async {
    final String encoded = jsonEncode(albums.map((a) => a.toJson()).toList());
    await prefs.setString(_albumsKey, encoded);
  }

  static const String _vaultKey = 'lumina_vault_items';
  static const String _pinKey = 'lumina_vault_pin';

  // --- PRIVATE VAULT ---

  static Future<List<String>> getVaultItems() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_vaultKey) ?? [];
  }

  static Future<List<String>> toggleVaultItem(String photoId) async {
    final prefs = await SharedPreferences.getInstance();
    final vaultItems = prefs.getStringList(_vaultKey) ?? [];

    if (vaultItems.contains(photoId)) {
      vaultItems.remove(photoId);
    } else {
      vaultItems.add(photoId);
      // Remove from favorites as well if locked
      final favorites = prefs.getStringList(_favoritesKey) ?? [];
      if (favorites.contains(photoId)) {
        favorites.remove(photoId);
        await prefs.setStringList(_favoritesKey, favorites);
      }
    }

    await prefs.setStringList(_vaultKey, vaultItems);
    return vaultItems;
  }

  static Future<bool> isInVault(String photoId) async {
    final vaultItems = await getVaultItems();
    return vaultItems.contains(photoId);
  }

  static Future<String?> getVaultPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey);
  }

  static Future<void> setVaultPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
  }

  /// Add multiple items to the vault in a single batch operation.
  static Future<void> addBatchToVault(List<String> photoIds) async {
    final prefs = await SharedPreferences.getInstance();
    final vaultItems = prefs.getStringList(_vaultKey) ?? [];
    final favorites = prefs.getStringList(_favoritesKey) ?? [];

    for (final id in photoIds) {
      if (!vaultItems.contains(id)) {
        vaultItems.add(id);
      }
      favorites.remove(id);
    }

    await prefs.setStringList(_vaultKey, vaultItems);
    await prefs.setStringList(_favoritesKey, favorites);
  }

  /// Add multiple items to an album in a single batch operation.
  static Future<void> addBatchToAlbum(String albumId, List<String> photoIds) async {
    final prefs = await SharedPreferences.getInstance();
    final albums = await getAlbums();

    for (var album in albums) {
      if (album.id == albumId) {
        for (final id in photoIds) {
          if (!album.photoIds.contains(id)) {
            album.photoIds.add(id);
          }
        }
      }
    }

    await _saveAlbums(prefs, albums);
  }

  static String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }
}

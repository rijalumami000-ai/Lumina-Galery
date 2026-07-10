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

  // --- TRASH BIN ---
  static const String _trashKey = 'lumina_trash_items';
  static const int trashRetentionDays = 30;

  /// Get all trash items (auto-cleans expired items).
  static Future<List<TrashItem>> getTrashItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? trashJson = prefs.getString(_trashKey);
    if (trashJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(trashJson);
      final items = decoded.map((item) => TrashItem.fromJson(item)).toList();
      
      // Auto-clean expired items (older than 30 days)
      final now = DateTime.now();
      final validItems = items.where((item) {
        final deletedDate = DateTime.tryParse(item.deletedAt);
        if (deletedDate == null) return false;
        return now.difference(deletedDate).inDays < trashRetentionDays;
      }).toList();

      // Save cleaned list if any expired items were removed
      if (validItems.length != items.length) {
        await _saveTrash(prefs, validItems);
      }

      return validItems;
    } catch (e) {
      return [];
    }
  }

  /// Move an item to trash (soft delete).
  static Future<void> moveToTrash(String photoId) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getTrashItems();

    // Don't add duplicates
    if (items.any((t) => t.photoId == photoId)) return;

    items.add(TrashItem(
      photoId: photoId,
      deletedAt: DateTime.now().toIso8601String(),
    ));

    await _saveTrash(prefs, items);

    // Also remove from favorites
    final favorites = prefs.getStringList(_favoritesKey) ?? [];
    if (favorites.contains(photoId)) {
      favorites.remove(photoId);
      await prefs.setStringList(_favoritesKey, favorites);
    }
  }

  /// Move multiple items to trash in batch.
  static Future<void> moveBatchToTrash(List<String> photoIds) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getTrashItems();
    final existingIds = items.map((t) => t.photoId).toSet();
    final now = DateTime.now().toIso8601String();

    for (final id in photoIds) {
      if (!existingIds.contains(id)) {
        items.add(TrashItem(photoId: id, deletedAt: now));
      }
    }

    await _saveTrash(prefs, items);

    // Also remove from favorites
    final favorites = prefs.getStringList(_favoritesKey) ?? [];
    favorites.removeWhere((f) => photoIds.contains(f));
    await prefs.setStringList(_favoritesKey, favorites);
  }

  /// Restore an item from trash (undo soft delete).
  static Future<void> restoreFromTrash(String photoId) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getTrashItems();
    items.removeWhere((t) => t.photoId == photoId);
    await _saveTrash(prefs, items);
  }

  /// Restore multiple items from trash.
  static Future<void> restoreBatchFromTrash(List<String> photoIds) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getTrashItems();
    items.removeWhere((t) => photoIds.contains(t.photoId));
    await _saveTrash(prefs, items);
  }

  /// Permanently delete an item from trash (remove the trash record).
  static Future<void> permanentDeleteFromTrash(String photoId) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getTrashItems();
    items.removeWhere((t) => t.photoId == photoId);
    await _saveTrash(prefs, items);
  }

  /// Empty all trash items.
  static Future<void> emptyTrash() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trashKey, '[]');
  }

  /// Check if an item is in trash.
  static Future<bool> isInTrash(String photoId) async {
    final items = await getTrashItems();
    return items.any((t) => t.photoId == photoId);
  }

  /// Get all trashed photo IDs (for filtering from gallery).
  static Future<Set<String>> getTrashIds() async {
    final items = await getTrashItems();
    return items.map((t) => t.photoId).toSet();
  }

  static Future<void> _saveTrash(SharedPreferences prefs, List<TrashItem> items) async {
    final String encoded = jsonEncode(items.map((t) => t.toJson()).toList());
    await prefs.setString(_trashKey, encoded);
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

/// Represents a trashed media item with its deletion timestamp.
class TrashItem {
  final String photoId;
  final String deletedAt;

  TrashItem({required this.photoId, required this.deletedAt});

  factory TrashItem.fromJson(Map<String, dynamic> json) {
    return TrashItem(
      photoId: json['photoId'] ?? '',
      deletedAt: json['deletedAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'photoId': photoId,
    'deletedAt': deletedAt,
  };

  /// Days remaining before permanent deletion.
  int get daysRemaining {
    final deleted = DateTime.tryParse(deletedAt);
    if (deleted == null) return 0;
    final expiry = deleted.add(const Duration(days: DatabaseHelper.trashRetentionDays));
    return expiry.difference(DateTime.now()).inDays.clamp(0, DatabaseHelper.trashRetentionDays);
  }
}

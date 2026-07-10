import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../models/photo.dart';
import '../storage/database.dart';
import '../utils/mock_data.dart';
import '../utils/media_loader.dart';
import '../widgets/glass_box.dart';
import 'detail_screen.dart';
import 'vault_lock_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<GalleryItem> _mediaItems = [];
  List<GalleryItem> _favoriteItems = [];
  List<CustomAlbum> _albums = [];
  CustomAlbum? _selectedAlbum;
  bool _isLoading = true;

  final TextEditingController _albumNameController = TextEditingController();
  final TextEditingController _albumDescController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final localItems = await MediaLoader.loadLocalMedia();
    final vaultItems = await DatabaseHelper.getVaultItems();
    final trashIds = await DatabaseHelper.getTrashIds();
    List<GalleryItem> items = [];
    if (localItems.isNotEmpty) {
      items = localItems.where((item) => !vaultItems.contains(item.id) && !trashIds.contains(item.id)).toList();
    } else {
      // Fallback mock items
      final mockItems = MOCK_PHOTOS.map((p) => GalleryItem(
        id: p.id,
        title: p.title,
        description: p.description,
        category: p.category,
        type: GalleryItemType.image,
        mockPhoto: p,
        dateText: p.date,
      )).toList();
      items = mockItems.where((item) => !vaultItems.contains(item.id) && !trashIds.contains(item.id)).toList();
    }

    final favIds = await DatabaseHelper.getFavorites();
    final favs = items.where((item) => favIds.contains(item.id)).toList();
    final albs = await DatabaseHelper.getAlbums();

    if (mounted) {
      setState(() {
        _mediaItems = items;
        _favoriteItems = favs;
        _albums = albs;
        _isLoading = false;
        
        if (_selectedAlbum != null) {
          try {
            _selectedAlbum = albs.firstWhere((a) => a.id == _selectedAlbum!.id);
          } catch (_) {
            _selectedAlbum = null;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _albumNameController.dispose();
    _albumDescController.dispose();
    super.dispose();
  }

  void _showCreateAlbumDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassBox(
            borderRadius: 24,
            blur: 25,
            tintColor: Colors.black.withOpacity(0.75),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.0,
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'New Album',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _albumNameController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLength: 20,
                  decoration: InputDecoration(
                    hintText: 'Album Name',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: const TextStyle(color: Colors.white30, fontSize: 10),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _albumDescController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLength: 60,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Description (Optional)',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: const TextStyle(color: Colors.white30, fontSize: 10),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _albumNameController.clear();
                          _albumDescController.clear();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final name = _albumNameController.text.trim();
                          if (name.isEmpty) return;

                          final updated = await DatabaseHelper.createAlbum(
                            name, 
                            _albumDescController.text.trim()
                          );
                          
                          setState(() {
                            _albums = updated;
                          });

                          _albumNameController.clear();
                          _albumDescController.clear();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade500,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Create',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteAlbum(String id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text('Delete Album', style: TextStyle(color: Colors.white)),
          content: const Text('Are you sure you want to delete this album? Media inside will not be deleted.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () async {
                final updated = await DatabaseHelper.deleteAlbum(id);
                setState(() {
                  _albums = updated;
                  if (_selectedAlbum?.id == id) {
                    _selectedAlbum = null;
                  }
                });
                Navigator.of(context).pop();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  GalleryItem? _getItemById(String id) {
    try {
      return _mediaItems.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadData(); // Sync list values automatically on navigate-back

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F11),
        body: Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          children: [
            // Header Title with Vault Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Library',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your personal custom spaces & favorites',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const VaultLockScreen()),
                      );
                    },
                    child: GlassBox(
                      width: 44,
                      height: 44,
                      borderRadius: 22,
                      blur: 10,
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Albums Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ALBUMS (${_albums.length})',
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.blue),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _showCreateAlbumDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                _albums.isEmpty
                    ? GlassBox(
                        borderRadius: 16,
                        blur: 10,
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.create_new_folder_rounded, color: Colors.white.withOpacity(0.3), size: 36),
                              const SizedBox(height: 12),
                              Text(
                                'Create albums to group your media files',
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 155,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          itemCount: _albums.length,
                          itemBuilder: (context, index) {
                            final album = _albums[index];
                            final hasCover = album.photoIds.isNotEmpty;
                            final coverItem = hasCover ? _getItemById(album.photoIds.first) : null;

                            return Stack(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedAlbum = album;
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 16.0),
                                    width: 120,
                                    child: GlassBox(
                                      borderRadius: 16,
                                      blur: 10,
                                      padding: EdgeInsets.zero,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Album cover
                                          Expanded(
                                            child: Container(
                                              width: 120,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.04),
                                              ),
                                              child: coverItem == null
                                                  ? Icon(
                                                      Icons.collections_rounded,
                                                      color: Colors.white.withOpacity(0.3),
                                                      size: 32,
                                                    )
                                                  : ClipRRect(
                                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                                      child: coverItem.isLocal
                                                          ? AssetEntityImage(
                                                              coverItem.asset!,
                                                              isOriginal: false,
                                                              fit: BoxFit.cover,
                                                            )
                                                          : Image.network(
                                                              coverItem.mockPhoto!.thumbnailUrl,
                                                              fit: BoxFit.cover,
                                                            ),
                                                    ),
                                            ),
                                          ),
                                          // Album details text
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  album.name,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${album.photoIds.length} items',
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.5),
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Delete album floating button
                                Positioned(
                                  top: 0,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () => _deleteAlbum(album.id),
                                    child: GlassBox(
                                      width: 24,
                                      height: 24,
                                      borderRadius: 12,
                                      blur: 5,
                                      tintColor: Colors.black.withOpacity(0.4),
                                      border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1),
                                      child: const Center(
                                        child: Icon(Icons.close_rounded, color: Colors.redAccent, size: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 28),

            // Custom selected album grid
            if (_selectedAlbum != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ALBUM: ${_selectedAlbum!.name.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        if (_selectedAlbum!.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              _selectedAlbum!.description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedAlbum = null;
                      });
                    },
                    child: const Text('Close', style: TextStyle(color: Colors.blue, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              _selectedAlbum!.photoIds.isEmpty
                  ? GlassBox(
                      borderRadius: 16,
                      blur: 10,
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'Album is empty. Go to Home or Explore to add media files!',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _selectedAlbum!.photoIds.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        final id = _selectedAlbum!.photoIds[index];
                        final item = _getItemById(id);
                        if (item == null) return const SizedBox();
                        final isVideo = item.type == GalleryItemType.video;

                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => DetailScreen(item: item)),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16.0),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Thumbnail
                                item.isLocal
                                    ? AssetEntityImage(
                                        item.asset!,
                                        isOriginal: false,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.network(item.mockPhoto!.thumbnailUrl, fit: BoxFit.cover),
                                
                                // Video indicator
                                if (isVideo)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GlassBox(
                                      borderRadius: 12,
                                      blur: 5,
                                      tintColor: Colors.black.withOpacity(0.4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 10),
                                    ),
                                  ),

                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: GlassBox(
                                    borderRadius: 0,
                                    blur: 5,
                                    border: Border(
                                      top: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 28),
            ],

            // Favorites Section
            Text(
              'FAVORITE ITEMS (${_favoriteItems.length})',
              style: const TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            
            _favoriteItems.isEmpty
                ? GlassBox(
                    borderRadius: 16,
                    blur: 10,
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            'Tap the heart icon on any photo or video to add it here',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _favoriteItems.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = _favoriteItems[index];
                      final isVideo = item.type == GalleryItemType.video;

                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => DetailScreen(item: item)),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16.0),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Thumbnail
                              item.isLocal
                                  ? AssetEntityImage(
                                      item.asset!,
                                      isOriginal: false,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(item.mockPhoto!.thumbnailUrl, fit: BoxFit.cover),
                              
                              // Video indicator
                              if (isVideo)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GlassBox(
                                    borderRadius: 12,
                                    blur: 5,
                                    tintColor: Colors.black.withOpacity(0.4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 10),
                                  ),
                                ),

                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: GlassBox(
                                  borderRadius: 0,
                                  blur: 5,
                                  border: Border(
                                    top: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            
            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }
}

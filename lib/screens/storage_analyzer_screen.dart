import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../models/photo.dart';
import '../utils/mock_data.dart';
import '../utils/media_loader.dart';
import '../widgets/glass_box.dart';
import 'detail_screen.dart';

class _MediaSizeInfo {
  final GalleryItem item;
  final int bytes;

  _MediaSizeInfo({required this.item, required this.bytes});
}

class StorageAnalyzerScreen extends StatefulWidget {
  const StorageAnalyzerScreen({Key? key}) : super(key: key);

  @override
  _StorageAnalyzerScreenState createState() => _StorageAnalyzerScreenState();
}

class _StorageAnalyzerScreenState extends State<StorageAnalyzerScreen> {
  List<_MediaSizeInfo> _allMedia = [];
  int _totalSize = 0;
  int _photoSize = 0;
  int _videoSize = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpaceData();
  }

  Future<void> _loadSpaceData() async {
    final localItems = await MediaLoader.loadLocalMedia();
    final List<_MediaSizeInfo> items = [];
    int totalBytes = 0;
    int photoBytes = 0;
    int videoBytes = 0;

    if (localItems.isNotEmpty) {
      final futures = localItems.map((item) async {
        try {
          final size = await item.asset!.fileSize;
          return _MediaSizeInfo(item: item, bytes: size);
        } catch (_) {
          final size = item.type == GalleryItemType.video 
              ? 25 * 1024 * 1024 
              : 2 * 1024 * 1024;
          return _MediaSizeInfo(item: item, bytes: size);
        }
      });
      final resolved = await Future.wait(futures);
      items.addAll(resolved);
    } else {
      // Fallback Mock items with simulated sizes
      final mockItems = MOCK_PHOTOS.map((p) => GalleryItem(
        id: p.id,
        title: p.title,
        description: p.description,
        category: p.category,
        type: GalleryItemType.image,
        mockPhoto: p,
        dateText: p.date,
      )).toList();

      for (int i = 0; i < mockItems.length; i++) {
        final isVideo = i % 4 == 0;
        final bytes = isVideo 
            ? (18 + (i * 9)) * 1024 * 1024 
            : (2 + (i * 0.75)) * 1024 * 1024;
        
        final item = isVideo 
            ? GalleryItem(
                id: mockItems[i].id,
                title: mockItems[i].title,
                description: mockItems[i].description,
                category: mockItems[i].category,
                type: GalleryItemType.video,
                mockPhoto: mockItems[i].mockPhoto,
                dateText: mockItems[i].dateText,
                durationText: "0:${30 + i}",
              )
            : mockItems[i];
        
        items.add(_MediaSizeInfo(item: item, bytes: bytes.round()));
      }
    }

    // Sort by largest size
    items.sort((a, b) => b.bytes.compareTo(a.bytes));

    for (var info in items) {
      totalBytes += info.bytes;
      if (info.item.type == GalleryItemType.video) {
        videoBytes += info.bytes;
      } else {
        photoBytes += info.bytes;
      }
    }

    if (mounted) {
      setState(() {
        _allMedia = items;
        _totalSize = totalBytes;
        _photoSize = photoBytes;
        _videoSize = videoBytes;
        _isLoading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    final double mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      final double gb = mb / 1024;
      return "${gb.toStringAsFixed(1)} GB";
    }
    return "${mb.toStringAsFixed(1)} MB";
  }

  Future<void> _deleteAsset(BuildContext context, _MediaSizeInfo mediaInfo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text('Delete File', style: TextStyle(color: Colors.white)),
          content: Text(
            'Are you sure you want to delete "${mediaInfo.item.title}" from your storage? This will free up ${_formatBytes(mediaInfo.bytes)}.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      if (mediaInfo.item.isLocal) {
        try {
          final List<String> result = await PhotoManager.editor.deleteWithIds([mediaInfo.item.id]);
          if (result.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File deleted successfully from storage.'), backgroundColor: Colors.green),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete file: $e'), backgroundColor: Colors.redAccent),
          );
        }
      } else {
        // Mock delete simulation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mock file deleted successfully (simulated).'), backgroundColor: Colors.green),
        );
      }

      // Reload storage data
      await _loadSpaceData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double photoPercent = _totalSize > 0 ? (_photoSize / _totalSize) : 0.0;
    final double videoPercent = _totalSize > 0 ? (_videoSize / _totalSize) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: Stack(
        children: [
          // Background ambient lights
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade900.withOpacity(0.1),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: GlassBox(
                          width: 40,
                          height: 40,
                          borderRadius: 20,
                          blur: 5,
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Storage Space Analyzer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Identify and clean up heavy media files',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      children: [
                        // Storage Space Gauge Card
                        GlassBox(
                          borderRadius: 24,
                          blur: 15,
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL ANALYZED SPACE',
                                style: TextStyle(
                                  color: Colors.white30,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatBytes(_totalSize),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Dual-color progress indicator bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  height: 8,
                                  width: double.infinity,
                                  color: Colors.white.withOpacity(0.08),
                                  child: Row(
                                    children: [
                                      if (photoPercent > 0)
                                        Flexible(
                                          flex: (photoPercent * 100).round(),
                                          child: Container(color: Colors.blue.shade400),
                                        ),
                                      if (videoPercent > 0)
                                        Flexible(
                                          flex: (videoPercent * 100).round(),
                                          child: Container(color: Colors.orange.shade400),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Legends details
                              Row(
                                children: [
                                  _buildLegendItem('Photos', _formatBytes(_photoSize), Colors.blue.shade400),
                                  const SizedBox(width: 24),
                                  _buildLegendItem('Videos', _formatBytes(_videoSize), Colors.orange.shade400),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Section Title
                        const Text(
                          'HEAVIEST MEDIA FILES',
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // List of files sorted by size
                        _allMedia.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                                  child: Text(
                                    'No media files found.',
                                    style: TextStyle(color: Colors.white.withOpacity(0.4)),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _allMedia.length > 25 ? 25 : _allMedia.length, // show top 25
                                itemBuilder: (context, index) {
                                  final info = _allMedia[index];
                                  final item = info.item;
                                  final isVideo = item.type == GalleryItemType.video;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: GlassBox(
                                      borderRadius: 16,
                                      blur: 5,
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          // Small square thumbnail
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(builder: (context) => DetailScreen(item: item)),
                                              );
                                            },
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(10.0),
                                              child: SizedBox(
                                                width: 50,
                                                height: 50,
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    item.isLocal
                                                        ? AssetEntityImage(
                                                            item.asset!,
                                                            isOriginal: false,
                                                            fit: BoxFit.cover,
                                                          )
                                                        : Image.network(item.mockPhoto!.thumbnailUrl, fit: BoxFit.cover),
                                                    if (isVideo)
                                                      Center(
                                                        child: Container(
                                                          width: 20,
                                                          height: 20,
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: Colors.black.withOpacity(0.5),
                                                          ),
                                                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          
                                          // Info details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  isVideo ? 'Video format' : 'Image format',
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.4),
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // File size tag
                                          Text(
                                            _formatBytes(info.bytes),
                                            style: TextStyle(
                                              color: isVideo ? Colors.orange.shade300 : Colors.blue.shade300,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // Delete trash button
                                          GestureDetector(
                                            onTap: () => _deleteAsset(context, info),
                                            child: Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.redAccent.withOpacity(0.1),
                                              ),
                                              child: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: Colors.redAccent,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String title, String size, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              size,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

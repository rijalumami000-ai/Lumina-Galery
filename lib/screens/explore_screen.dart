import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../models/photo.dart';
import '../storage/database.dart';
import '../utils/mock_data.dart';
import '../utils/media_loader.dart';
import '../widgets/glass_box.dart';
import 'detail_screen.dart';
import 'storage_analyzer_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<GalleryItem> _mediaItems = [];
  bool _isLoading = true;
  int _favCount = 0;
  int _albumCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadMedia();
  }

  Future<void> _loadStats() async {
    final favs = await DatabaseHelper.getFavorites();
    final albs = await DatabaseHelper.getAlbums();
    if (mounted) {
      setState(() {
        _favCount = favs.length;
        _albumCount = albs.length;
      });
    }
  }

  Future<void> _loadMedia() async {
    final localItems = await MediaLoader.loadLocalMedia();
    final vaultItems = await DatabaseHelper.getVaultItems();
    if (mounted) {
      setState(() {
        if (localItems.isNotEmpty) {
          _mediaItems = localItems.where((item) => !vaultItems.contains(item.id)).toList();
        } else {
          // Fallback to mock photos mapped to GalleryItem
          final mockItems = MOCK_PHOTOS.map((p) => GalleryItem(
            id: p.id,
            title: p.title,
            description: p.description,
            category: p.category,
            type: GalleryItemType.image,
            mockPhoto: p,
            dateText: p.date,
          )).toList();
          _mediaItems = mockItems.where((item) => !vaultItems.contains(item.id)).toList();
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _loadStats(); // Keep stats updated

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F11),
        body: Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );
    }

    // Filter items based on search query
    final searchedItems = _searchQuery.isEmpty
        ? _mediaItems
        : _mediaItems.where((item) {
            final query = _searchQuery.toLowerCase();
            final titleMatch = item.title.toLowerCase().contains(query);
            final descMatch = item.description.toLowerCase().contains(query);
            
            if (item.isLocal) {
              final mimeMatch = item.asset!.mimeType?.toLowerCase().contains(query) ?? false;
              final typeMatch = (item.type == GalleryItemType.video ? 'video' : 'photo').contains(query);
              return titleMatch || descMatch || mimeMatch || typeMatch;
            } else {
              final mock = item.mockPhoto!;
              final cameraMatch = mock.exif.camera.toLowerCase().contains(query);
              final authorMatch = mock.author.toLowerCase().contains(query);
              final catMatch = mock.category.toLowerCase().contains(query);
              return titleMatch || descMatch || cameraMatch || authorMatch || catMatch;
            }
          }).toList();

    // Determine chart details dynamically
    final isLocal = _mediaItems.first.isLocal;
    final Map<String, int> chartCounts = {};
    String chartTitle = 'Camera Gear Distribution';
    IconData chartIcon = Icons.bar_chart_rounded;

    if (isLocal) {
      chartTitle = 'Media Formats (MIME)';
      chartIcon = Icons.data_usage_rounded;
      for (var item in _mediaItems) {
        final mime = item.asset!.mimeType?.split('/').last.toUpperCase() ?? 'OTHER';
        chartCounts[mime] = (chartCounts[mime] ?? 0) + 1;
      }
    } else {
      chartTitle = 'Camera Gear Distribution';
      chartIcon = Icons.camera_alt_rounded;
      for (var item in _mediaItems) {
        final brand = item.mockPhoto!.exif.camera.split(' ')[0];
        chartCounts[brand] = (chartCounts[brand] ?? 0) + 1;
      }
    }

    final int totalChartSum = chartCounts.values.fold(0, (a, b) => a + b);
    final totalVideos = _mediaItems.where((item) => item.type == GalleryItemType.video).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Explore Lumina',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLocal 
                        ? 'Search and analyze local storage MIME formats'
                        : 'Discover shots, search and analyze EXIF statistics',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
              child: GlassBox(
                borderRadius: 16,
                blur: 10,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: isLocal 
                        ? 'Search file name, type (photo/video), or MIME...' 
                        : 'Search title, photographer, or camera...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                    border: InputBorder.none,
                    icon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.5)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
            ),

            // Main Content Area
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                children: [
                  // Show stats ONLY if search query is empty
                  if (_searchQuery.isEmpty) ...[
                    const Text(
                      'GALLERY OVERVIEW',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Metrics cards row
                    Row(
                      children: [
                        _buildMetricTile(
                          isLocal ? 'Videos' : 'Photos', 
                          isLocal ? '$totalVideos' : '${_mediaItems.length}', 
                          Colors.blue.shade400
                        ),
                        const SizedBox(width: 12),
                        _buildMetricTile('Favorites', '$_favCount', Colors.red.shade400),
                        const SizedBox(width: 12),
                        _buildMetricTile('Albums', '$_albumCount', Colors.green.shade400),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Stats graph card
                    GlassBox(
                      borderRadius: 20,
                      blur: 15,
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(chartIcon, color: Colors.blue, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                chartTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Column(
                            children: chartCounts.entries.map((entry) {
                              final label = entry.key;
                              final count = entry.value;
                              final percentage = (count / totalChartSum) * 100;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: count / totalChartSum,
                                          backgroundColor: Colors.white.withOpacity(0.08),
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        '$count (${percentage.round()}%)',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Storage Analyzer Launcher Card
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const StorageAnalyzerScreen()),
                        );
                      },
                      child: GlassBox(
                        borderRadius: 20,
                        blur: 15,
                        tintColor: Colors.blue.shade900.withOpacity(0.12),
                        border: Border.all(
                          color: Colors.blue.shade500.withOpacity(0.3),
                          width: 1.0,
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.shade500.withOpacity(0.2),
                              ),
                              child: Icon(Icons.disc_full_rounded, color: Colors.blue.shade400, size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Storage Analyzer',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Analyze space and clean up heavy media files',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white.withOpacity(0.4),
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Discovery Title
                  Text(
                    _searchQuery.isEmpty ? 'DISCOVER ALL ITEMS' : 'SEARCH RESULTS (${searchedItems.length})',
                    style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (searchedItems.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded, color: Colors.white.withOpacity(0.3), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No items match "$_searchQuery"',
                              style: TextStyle(color: Colors.white.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // Simple search grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: searchedItems.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        final item = searchedItems[index];
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
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 10),
                                          if (item.durationText.isNotEmpty) ...[
                                            const SizedBox(width: 2),
                                            Text(
                                              item.durationText,
                                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),
                                  ),

                                // Title Glass Overlay
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: GlassBox(
                                    borderRadius: 0,
                                    blur: 5,
                                    border: Border(
                                      top: BorderSide(
                                        color: Colors.white.withOpacity(0.06),
                                        width: 1,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          item.isLocal ? 'Local Storage' : item.mockPhoto!.author,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 9,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String count, Color color) {
    return Expanded(
      child: GlassBox(
        borderRadius: 16,
        blur: 15,
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/photo.dart';
import '../storage/database.dart';
import '../utils/mock_data.dart';
import '../widgets/glass_box.dart';
import 'detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _favCount = 0;
  int _albumCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _loadStats(); // keep stats updated when navigating back
    
    // Filter photos based on search query
    final searchedPhotos = _searchQuery.isEmpty
        ? MOCK_PHOTOS
        : MOCK_PHOTOS.where((photo) =>
            photo.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            photo.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            photo.author.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            photo.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            photo.exif.camera.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();

    // Calculate camera gear distribution stats
    final Map<String, int> cameraCounts = {};
    for (var photo in MOCK_PHOTOS) {
      final brand = photo.exif.camera.split(' ')[0];
      cameraCounts[brand] = (cameraCounts[brand] ?? 0) + 1;
    }
    final int totalCameras = cameraCounts.values.fold(0, (a, b) => a + b);

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
                    'Discover shots, search and analyze EXIF statistics',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

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
                    hintText: 'Search title, photographer, or camera...',
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
                    // Staggered overview section title
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
                        _buildMetricTile('Photos', '${MOCK_PHOTOS.length}', Colors.blue.shade400),
                        const SizedBox(width: 12),
                        _buildMetricTile('Favorites', '$_favCount', Colors.red.shade400),
                        const SizedBox(width: 12),
                        _buildMetricTile('Albums', '$_albumCount', Colors.green.shade400),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Camera stats graph card
                    GlassBox(
                      borderRadius: 20,
                      blur: 15,
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.bar_chart_rounded, color: Colors.blue, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Camera Gear Distribution',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Column(
                            children: cameraCounts.entries.map((entry) {
                              final brand = entry.key;
                              final count = entry.value;
                              final percentage = (count / totalCameras) * 100;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        brand,
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
                                          value: count / totalCameras,
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
                    const SizedBox(height: 24),
                  ],

                  // Discovery Title
                  Text(
                    _searchQuery.isEmpty ? 'DISCOVER ALL PHOTOS' : 'SEARCH RESULTS (${searchedPhotos.length})',
                    style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (searchedPhotos.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded, color: Colors.white.withOpacity(0.3), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No photos match "$_searchQuery"',
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
                      itemCount: searchedPhotos.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        final photo = searchedPhotos[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => DetailScreen(photo: photo)),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16.0),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(photo.thumbnailUrl, fit: BoxFit.cover),
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
                                          photo.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          photo.author,
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
                  
                  // Margin spacing at bottom
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

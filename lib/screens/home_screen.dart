import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../models/photo.dart';
import '../utils/mock_data.dart';
import '../utils/media_loader.dart';
import '../storage/database.dart';
import '../widgets/glass_box.dart';
import '../widgets/photo_card.dart';
import 'detail_screen.dart';
import 'ambient_slideshow_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  List<GalleryItem> _mediaItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    final localItems = await MediaLoader.loadLocalMedia();
    final vaultItems = await DatabaseHelper.getVaultItems();
    if (mounted) {
      setState(() {
        if (localItems.isNotEmpty) {
          _mediaItems = localItems.where((item) => !vaultItems.contains(item.id)).toList();
        } else {
          // Fallback to mock photos
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
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F11),
        body: Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );
    }

    // Featured items (first 3 from our active items list)
    final featuredItems = _mediaItems.take(3).toList();

    // Dynamically build category list depending on items
    final Set<String> dynamicCategories = {"All"};
    for (var item in _mediaItems) {
      if (item.isLocal) {
        dynamicCategories.add(item.type == GalleryItemType.video ? 'Video' : 'Photos');
      } else {
        dynamicCategories.add(item.category);
      }
    }
    final List<String> currentCategories = dynamicCategories.toList();

    // Filter items based on selected category
    final filteredItems = _selectedCategory == 'All'
        ? _mediaItems
        : _mediaItems.where((item) {
            if (item.isLocal) {
              if (_selectedCategory == 'Video') return item.type == GalleryItemType.video;
              if (_selectedCategory == 'Photos') return item.type == GalleryItemType.image;
              return false;
            } else {
              return item.category == _selectedCategory;
            }
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: Stack(
        children: [
          // Background ambient light
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade500.withOpacity(0.12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade500.withOpacity(0.08),
                    blurRadius: 100,
                    spreadRadius: 80,
                  )
                ],
              ),
            ),
          ),
          
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Brand Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lumina',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                            ),
                            Text(
                              _mediaItems.first.isLocal
                                  ? 'Your Native Device Gallery'
                                  : 'Immersive Fine Art Gallery',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        // Action Buttons (Slideshow & Refresh)
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_mediaItems.isNotEmpty) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => AmbientSlideshowScreen(items: _mediaItems),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue.shade500.withOpacity(0.15),
                                  border: Border.all(
                                    color: Colors.blue.shade500.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(Icons.play_circle_fill_rounded, color: Colors.blue.shade400, size: 20),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isLoading = true;
                                });
                                _loadMedia();
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.05),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.12),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Featured Section
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                        child: Text(
                          'FEATURED SHOTS',
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      
                      SizedBox(
                        height: 205,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          itemCount: featuredItems.length,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          itemBuilder: (context, index) {
                            final item = featuredItems[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => DetailScreen(item: item)),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 16.0),
                                width: size.width - 40,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Image
                                      item.isLocal
                                          ? AssetEntityImage(
                                              item.asset!,
                                              isOriginal: true,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.network(
                                              item.mockPhoto!.url,
                                              fit: BoxFit.cover,
                                            ),
                                      // Floating Title Tag
                                      Positioned(
                                        bottom: 16,
                                        left: 16,
                                        right: 16,
                                        child: GlassBox(
                                          borderRadius: 16,
                                          blur: 15,
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      item.title,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      item.isLocal ? 'Local Media' : 'by ${item.mockPhoto!.author}',
                                                      style: TextStyle(
                                                        color: Colors.white.withOpacity(0.6),
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Icon(
                                                Icons.arrow_outward_rounded,
                                                color: Colors.blue,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Category list
                SliverToBoxAdapter(
                  child: Container(
                    height: 50,
                    margin: const EdgeInsets.symmetric(vertical: 24.0),
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      itemCount: currentCategories.length,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      itemBuilder: (context, index) {
                        final cat = currentCategories[index];
                        final isSelected = _selectedCategory == cat;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10.0),
                            child: GlassBox(
                              borderRadius: 24,
                              blur: 5,
                              tintColor: isSelected 
                                  ? Colors.blue.shade500.withOpacity(0.2) 
                                  : Colors.white.withOpacity(0.04),
                              border: Border.all(
                                color: isSelected 
                                    ? Colors.blue.shade500.withOpacity(0.6) 
                                    : Colors.white.withOpacity(0.06),
                                width: 1.0,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                              child: Center(
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Dynamic Staggered Masonry Grid List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EXPLORE ${_selectedCategory.toUpperCase()} (${filteredItems.length})',
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Column 1
                            Expanded(
                              child: Column(
                                children: _buildGridColumn(filteredItems, 0),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Column 2
                            Expanded(
                              child: Column(
                                children: _buildGridColumn(filteredItems, 1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 110),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGridColumn(List<GalleryItem> items, int columnIndex) {
    final columnWidgets = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      if (i % 2 == columnIndex) {
        final height = (i % 3 == 0) ? 220.0 : 155.0;
        columnWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: PhotoCard(item: items[i], height: height),
          ),
        );
      }
    }
    return columnWidgets;
  }
}

import 'package:flutter/material.dart';
import '../models/photo.dart';
import '../utils/mock_data.dart';
import '../widgets/glass_box.dart';
import '../widgets/photo_card.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // Featured shots (first 3)
    final featuredPhotos = MOCK_PHOTOS.sublist(0, 3);

    // Filtered grid photos
    final filteredPhotos = _selectedCategory == 'All'
        ? MOCK_PHOTOS
        : MOCK_PHOTOS.where((photo) => photo.category == _selectedCategory).toList();

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
                              'Immersive Fine Art Gallery',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        // Profile Avatar
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                              width: 1,
                            ),
                            image: const DecorationImage(
                              image: NetworkImage(
                                'https://images.unsplash.com/profile-1502914728514-411306c59b20?auto=format&fit=crop&w=64&h=64&q=80',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
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
                          itemCount: featuredPhotos.length,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          itemBuilder: (context, index) {
                            final photo = featuredPhotos[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => DetailScreen(photo: photo)),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 16.0),
                                width: size.width - 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                    width: 1,
                                  ),
                                  image: DecorationImage(
                                    image: NetworkImage(photo.url),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                child: Stack(
                                  children: [
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
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  photo.title,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  'by ${photo.author}',
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.6),
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
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
                      itemCount: CATEGORIES.length,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      itemBuilder: (context, index) {
                        final cat = CATEGORIES[index];
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
                          'EXPLORE ${_selectedCategory.toUpperCase()} (${filteredPhotos.length})',
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
                                children: _buildGridColumn(filteredPhotos, 0),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Column 2
                            Expanded(
                              child: Column(
                                children: _buildGridColumn(filteredPhotos, 1),
                              ),
                            ),
                          ],
                        ),
                        // Add extra padding at the bottom for the floating tab bar
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

  // Generates column items alternating height to simulate masonry look
  List<Widget> _buildGridColumn(List<Photo> photos, int columnIndex) {
    final columnWidgets = <Widget>[];
    for (int i = 0; i < photos.length; i++) {
      if (i % 2 == columnIndex) {
        // dynamic heights (e.g. index-based height alternate)
        final height = (i % 3 == 0) ? 220.0 : 155.0;
        columnWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: PhotoCard(photo: photos[i], height: height),
          ),
        );
      }
    }
    return columnWidgets;
  }
}

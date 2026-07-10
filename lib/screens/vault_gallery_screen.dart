import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../storage/database.dart';
import '../utils/mock_data.dart';
import '../utils/media_loader.dart';
import '../widgets/glass_box.dart';
import 'detail_screen.dart';

class VaultGalleryScreen extends StatefulWidget {
  const VaultGalleryScreen({Key? key}) : super(key: key);

  @override
  _VaultGalleryScreenState createState() => _VaultGalleryScreenState();
}

class _VaultGalleryScreenState extends State<VaultGalleryScreen> {
  List<GalleryItem> _vaultItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVaultData();
  }

  Future<void> _loadVaultData() async {
    final localItems = await MediaLoader.loadLocalMedia();
    List<GalleryItem> allItems = [];
    if (localItems.isNotEmpty) {
      allItems = localItems;
    } else {
      // Fallback mock items
      allItems = MOCK_PHOTOS.map((p) => GalleryItem(
        id: p.id,
        title: p.title,
        description: p.description,
        category: p.category,
        type: GalleryItemType.image,
        mockPhoto: p,
        dateText: p.date,
      )).toList();
    }

    final lockedIds = await DatabaseHelper.getVaultItems();
    final lockedItems = allItems.where((item) => lockedIds.contains(item.id)).toList();

    if (mounted) {
      setState(() {
        _vaultItems = lockedItems;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadVaultData(); // Refresh list on navigation back (e.g. if unlocked)

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
      body: Stack(
        children: [
          // Background ambient lights
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade800.withOpacity(0.08),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
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
                              Row(
                                children: [
                                  Icon(Icons.vpn_key_rounded, color: Colors.blue.shade400, size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Kubah Rahasia',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Private Glass Vault Gallery',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      // Lock icon indication
                      Icon(Icons.security_rounded, color: Colors.blue.shade400, size: 24),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Grid Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _vaultItems.isEmpty
                        ? Center(
                            child: GlassBox(
                              borderRadius: 24,
                              blur: 15,
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_reset_rounded,
                                    color: Colors.white.withOpacity(0.25),
                                    size: 64,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Kubah Rahasia Kosong',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Buka foto atau video publik di beranda, lalu ketuk ikon gembok di bagian atas untuk mengamankannya di sini.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 11.5,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _vaultItems.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.0,
                            ),
                            itemBuilder: (context, index) {
                              final item = _vaultItems[index];
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
                                      
                                      // Video play indicator
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

                                      // Text Title
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
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

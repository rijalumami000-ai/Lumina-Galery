import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../models/photo.dart';
import '../utils/mock_data.dart';
import '../utils/media_loader.dart';
import '../storage/database.dart';
import '../widgets/glass_box.dart';
import '../widgets/photo_card.dart';
import 'detail_screen.dart';
import 'ambient_slideshow_screen.dart';
import 'trash_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _selectedCategory = 'All';
  List<GalleryItem> _mediaItems = [];
  bool _isLoading = true;

  // --- Multi-select state ---
  bool _selectMode = false;
  final Set<String> _selectedIds = {};
  late AnimationController _batchBarController;
  late Animation<Offset> _batchBarSlide;

  @override
  void initState() {
    super.initState();
    _batchBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _batchBarSlide = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _batchBarController, curve: Curves.easeOutCubic));
    _loadMedia();
  }

  @override
  void dispose() {
    _batchBarController.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    final localItems = await MediaLoader.loadLocalMedia();
    final vaultItems = await DatabaseHelper.getVaultItems();
    final trashIds = await DatabaseHelper.getTrashIds();
    if (mounted) {
      setState(() {
        if (localItems.isNotEmpty) {
          _mediaItems = localItems.where((item) => !vaultItems.contains(item.id) && !trashIds.contains(item.id)).toList();
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
          _mediaItems = mockItems.where((item) => !vaultItems.contains(item.id) && !trashIds.contains(item.id)).toList();
        }
        _isLoading = false;
      });
    }
  }

  // --- Multi-select helpers ---
  void _enterSelectMode(String firstId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectMode = true;
      _selectedIds.clear();
      _selectedIds.add(firstId);
    });
    _batchBarController.forward();
  }

  void _exitSelectMode() {
    _batchBarController.reverse();
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _exitSelectMode();
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<GalleryItem> items) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.length == items.length) {
        _selectedIds.clear();
        _exitSelectMode();
      } else {
        _selectedIds.addAll(items.map((e) => e.id));
      }
    });
  }

  // --- Batch actions ---
  Future<void> _batchDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        icon: Icons.delete_rounded,
        iconColor: Colors.orangeAccent,
        title: 'Pindah $count Item ke Trash?',
        message: 'Media akan dipindahkan ke Trash Bin dan dihapus otomatis setelah 30 hari.',
        confirmText: 'Pindah ke Trash',
        confirmColor: Colors.orangeAccent,
      ),
    );
    if (confirmed != true) return;

    // Move to trash (soft delete) instead of permanent delete
    await DatabaseHelper.moveBatchToTrash(_selectedIds.toList());

    _exitSelectMode();
    setState(() { _isLoading = true; });
    await _loadMedia();

    if (mounted) {
      _showSuccessSnackbar('$count item dipindahkan ke Trash', Icons.delete_rounded);
    }
  }

  Future<void> _batchLockToVault() async {
    final count = _selectedIds.length;
    final pin = await DatabaseHelper.getVaultPin();

    // If no PIN is set, prompt to create one
    if (pin == null || pin.isEmpty) {
      final newPin = await _showPinDialog(isSetup: true);
      if (newPin == null) return;
      await DatabaseHelper.setVaultPin(newPin);
    } else {
      // Verify existing PIN
      final enteredPin = await _showPinDialog(isSetup: false);
      if (enteredPin == null || enteredPin != pin) {
        if (enteredPin != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('PIN salah!', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }
    }

    await DatabaseHelper.addBatchToVault(_selectedIds.toList());
    _exitSelectMode();
    setState(() { _isLoading = true; });
    await _loadMedia();

    if (mounted) {
      _showSuccessSnackbar('$count item dikunci ke Vault', Icons.lock_rounded);
    }
  }

  Future<void> _batchAddToAlbum() async {
    final albums = await DatabaseHelper.getAlbums();

    if (!mounted) return;

    String? selectedAlbumId;

    if (albums.isEmpty) {
      // Prompt to create a new album
      selectedAlbumId = await _showCreateAlbumDialog();
    } else {
      selectedAlbumId = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => _buildAlbumPickerSheet(albums),
      );
    }

    if (selectedAlbumId == null || selectedAlbumId == '__new__') {
      if (selectedAlbumId == '__new__') {
        selectedAlbumId = await _showCreateAlbumDialog();
      }
      if (selectedAlbumId == null) return;
    }

    await DatabaseHelper.addBatchToAlbum(selectedAlbumId, _selectedIds.toList());
    _exitSelectMode();

    if (mounted) {
      _showSuccessSnackbar('${_selectedIds.length} item ditambahkan ke album', Icons.photo_album_rounded);
    }
  }

  Future<String?> _showCreateAlbumDialog() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Album Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nama album...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.cyanAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('Batal', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final albums = await DatabaseHelper.createAlbum(name, '');
                Navigator.of(ctx).pop(albums.last.id);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: const Color(0xFF0A0A0A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Buat', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    nameController.dispose();
    return result;
  }

  Widget _buildAlbumPickerSheet(List<CustomAlbum> albums) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
      decoration: const BoxDecoration(
        color: Color(0xFF121218),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pilih Album',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // Create new album option
                ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.cyanAccent),
                  ),
                  title: const Text('Buat Album Baru', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.of(context).pop('__new__'),
                ),
                const Divider(color: Colors.white10, indent: 16, endIndent: 16),
                ...albums.map((album) => ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Center(
                      child: Text(
                        '${album.photoIds.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  title: Text(album.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${album.photoIds.length} item • ${album.createdAt}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                  ),
                  onTap: () => Navigator.of(context).pop(album.id),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<String?> _showPinDialog({required bool isSetup}) async {
    String pin = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void onDigit(String d) {
            if (pin.length < 4) {
              setDialogState(() { pin += d; });
              if (pin.length == 4) {
                Navigator.of(ctx).pop(pin);
              }
            }
          }
          void onDelete() {
            if (pin.isNotEmpty) {
              setDialogState(() { pin = pin.substring(0, pin.length - 1); });
            }
          }
          return AlertDialog(
            backgroundColor: const Color(0xFF0F0F18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isSetup ? Icons.lock_open_rounded : Icons.lock_rounded, color: Colors.cyanAccent, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    isSetup ? 'Buat PIN Vault' : 'Masukkan PIN Vault',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) => Container(
                      width: 16, height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < pin.length ? Colors.cyanAccent : Colors.transparent,
                        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5), width: 2),
                      ),
                    )),
                  ),
                  const SizedBox(height: 20),
                  // Numpad
                  ...List.generate(3, (row) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (col) {
                      final digit = '${row * 3 + col + 1}';
                      return _pinButton(digit, () => onDigit(digit));
                    }),
                  )),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _pinButton('', null, isEmpty: true),
                      _pinButton('0', () => onDigit('0')),
                      _pinButton('⌫', onDelete, isDelete: true),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pinButton(String label, VoidCallback? onTap, {bool isEmpty = false, bool isDelete = false}) {
    if (isEmpty) return const SizedBox(width: 64, height: 54);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64, height: 54,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.06),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isDelete ? Colors.cyanAccent : Colors.white,
              fontSize: isDelete ? 20 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Batal', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _showSuccessSnackbar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        duration: const Duration(seconds: 2),
      ),
    );
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
                color: Colors.blue.shade500.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade500.withValues(alpha: 0.08),
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
                // Brand Header (changes in select mode)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: _selectMode
                        ? _buildSelectModeHeader(filteredItems)
                        : _buildNormalHeader(),
                  ),
                ),

                // Featured Section (hidden in select mode)
                if (!_selectMode)
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
                                                          color: Colors.white.withValues(alpha: 0.6),
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
                                  ? Colors.blue.shade500.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.04),
                              border: Border.all(
                                color: isSelected 
                                    ? Colors.blue.shade500.withValues(alpha: 0.6) 
                                    : Colors.white.withValues(alpha: 0.06),
                                width: 1.0,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                              child: Center(
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
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

          // Floating Batch Action Bar (animated in from bottom)
          if (_selectMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _batchBarSlide,
                child: _buildBatchActionBar(),
              ),
            ),
        ],
      ),
    );
  }

  // --- Header widgets ---
  Widget _buildNormalHeader() {
    return Row(
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
              _mediaItems.isNotEmpty && _mediaItems.first.isLocal
                  ? 'Your Native Device Gallery'
                  : 'Immersive Fine Art Gallery',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        // Action Buttons (Slideshow, Trash, & Refresh)
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
                  color: Colors.blue.shade500.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.blue.shade500.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(Icons.play_circle_fill_rounded, color: Colors.blue.shade400, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const TrashScreen(),
                  ),
                );
                // Refresh content when returning from Trash bin
                _loadMedia();
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orangeAccent.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.orangeAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.orangeAccent, size: 20),
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
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectModeHeader(List<GalleryItem> items) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _exitSelectMode,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedIds.length} Dipilih',
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'dari ${items.length} item',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () => _selectAll(items),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: _selectedIds.length == items.length
                  ? Colors.cyanAccent.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: _selectedIds.length == items.length
                    ? Colors.cyanAccent.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              _selectedIds.length == items.length ? 'Batal Semua' : 'Pilih Semua',
              style: TextStyle(
                color: _selectedIds.length == items.length ? Colors.cyanAccent : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Batch Action Bar ---
  Widget _buildBatchActionBar() {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0F0F11).withValues(alpha: 0.0),
            const Color(0xFF0F0F11).withValues(alpha: 0.95),
            const Color(0xFF0F0F11),
          ],
        ),
      ),
      child: GlassBox(
        borderRadius: 20,
        blur: 20,
        tintColor: const Color(0xFF14142A).withValues(alpha: 0.8),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.15)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBatchButton(
              icon: Icons.delete_forever_rounded,
              label: 'Hapus',
              color: Colors.redAccent,
              onTap: _batchDelete,
            ),
            _buildBatchDivider(),
            _buildBatchButton(
              icon: Icons.lock_rounded,
              label: 'Vault',
              color: Colors.cyanAccent,
              onTap: _batchLockToVault,
            ),
            _buildBatchDivider(),
            _buildBatchButton(
              icon: Icons.photo_album_rounded,
              label: 'Album',
              color: Colors.purpleAccent,
              onTap: _batchAddToAlbum,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withValues(alpha: 0.1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.06),
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
            child: PhotoCard(
              item: items[i],
              height: height,
              selectMode: _selectMode,
              isSelected: _selectedIds.contains(items[i].id),
              onSelect: () => _toggleSelection(items[i].id),
              onLongPress: () {
                if (!_selectMode) {
                  _enterSelectMode(items[i].id);
                }
              },
            ),
          ),
        );
      }
    }
    return columnWidgets;
  }
}

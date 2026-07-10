import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../utils/mock_data.dart';
import '../utils/media_loader.dart';
import '../storage/database.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<TrashItem> _trashItems = [];
  List<GalleryItem> _allMedia = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final trashItems = await DatabaseHelper.getTrashItems();

    // Load all media to resolve thumbnails
    final localItems = await MediaLoader.loadLocalMedia();
    List<GalleryItem> allItems = [];
    if (localItems.isNotEmpty) {
      allItems = localItems;
    } else {
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

    if (mounted) {
      setState(() {
        _trashItems = trashItems;
        _allMedia = allItems;
        _isLoading = false;
      });
    }
  }

  GalleryItem? _resolveItem(String photoId) {
    try {
      return _allMedia.firstWhere((m) => m.id == photoId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _restoreItem(TrashItem item) async {
    await DatabaseHelper.restoreFromTrash(item.photoId);
    if (mounted) {
      _showSnackbar('Media dipulihkan ke galeri', Icons.restore_rounded, Colors.greenAccent);
      _loadData();
    }
  }

  Future<void> _permanentDelete(TrashItem item) async {
    final confirmed = await _showConfirmDialog(
      icon: Icons.delete_forever_rounded,
      iconColor: Colors.redAccent,
      title: 'Hapus Permanen?',
      message: 'Media ini akan dihapus secara permanen dan tidak bisa dipulihkan lagi.',
      confirmText: 'Hapus Permanen',
      confirmColor: Colors.redAccent,
    );
    if (confirmed != true) return;

    // Actually delete from device if local
    final resolved = _resolveItem(item.photoId);
    if (resolved != null && resolved.isLocal && resolved.asset != null) {
      await PhotoManager.editor.deleteWithIds([resolved.asset!.id]);
    }

    await DatabaseHelper.permanentDeleteFromTrash(item.photoId);
    if (mounted) {
      _showSnackbar('Media dihapus permanen', Icons.delete_forever_rounded, Colors.redAccent);
      _loadData();
    }
  }

  Future<void> _emptyTrash() async {
    if (_trashItems.isEmpty) return;

    final confirmed = await _showConfirmDialog(
      icon: Icons.delete_sweep_rounded,
      iconColor: Colors.redAccent,
      title: 'Kosongkan Trash?',
      message: 'Semua ${_trashItems.length} media akan dihapus permanen dari perangkat Anda.',
      confirmText: 'Kosongkan Semua',
      confirmColor: Colors.redAccent,
    );
    if (confirmed != true) return;

    // Delete all local assets permanently
    final assetIds = <String>[];
    for (final trash in _trashItems) {
      final resolved = _resolveItem(trash.photoId);
      if (resolved != null && resolved.isLocal && resolved.asset != null) {
        assetIds.add(resolved.asset!.id);
      }
    }

    if (assetIds.isNotEmpty) {
      await PhotoManager.editor.deleteWithIds(assetIds);
    }

    await DatabaseHelper.emptyTrash();
    if (mounted) {
      _showSnackbar('Trash dikosongkan', Icons.delete_sweep_rounded, Colors.redAccent);
      _loadData();
    }
  }

  Future<void> _restoreAll() async {
    if (_trashItems.isEmpty) return;

    final ids = _trashItems.map((t) => t.photoId).toList();
    await DatabaseHelper.restoreBatchFromTrash(ids);
    if (mounted) {
      _showSnackbar('Semua media dipulihkan', Icons.restore_rounded, Colors.greenAccent);
      _loadData();
    }
  }

  void _showSnackbar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Batal', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: Stack(
        children: [
          // Background ambient glow (red tint for trash)
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.05),
                    blurRadius: 100,
                    spreadRadius: 80,
                  )
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Trash Bin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                '${_trashItems.length} item • Auto-hapus 30 hari',
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
                      if (_trashItems.isNotEmpty)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded, color: Colors.white.withValues(alpha: 0.6)),
                          color: const Color(0xFF1A1A2E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          onSelected: (value) {
                            if (value == 'restore_all') _restoreAll();
                            if (value == 'empty') _emptyTrash();
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'restore_all',
                              child: Row(
                                children: [
                                  const Icon(Icons.restore_rounded, color: Colors.greenAccent, size: 20),
                                  const SizedBox(width: 10),
                                  const Text('Pulihkan Semua', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'empty',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                                  const SizedBox(width: 10),
                                  const Text('Kosongkan Trash', style: TextStyle(color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                      : _trashItems.isEmpty
                          ? _buildEmptyState()
                          : _buildTrashGrid(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
            ),
            child: Icon(Icons.delete_outline_rounded, color: Colors.white.withValues(alpha: 0.2), size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'Trash Kosong',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak ada media yang dihapus',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashGrid() {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: _trashItems.length,
      itemBuilder: (context, index) {
        final trashItem = _trashItems[index];
        final resolved = _resolveItem(trashItem.photoId);
        return _buildTrashTile(trashItem, resolved);
      },
    );
  }

  Widget _buildTrashTile(TrashItem trashItem, GalleryItem? resolved) {
    final daysLeft = trashItem.daysRemaining;
    final isUrgent = daysLeft <= 3;

    return GestureDetector(
      onTap: () => _showTrashItemActions(trashItem, resolved),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            if (resolved != null && resolved.isLocal && resolved.asset != null)
              AssetEntityImage(
                resolved.asset!,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize(200, 200),
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _placeholderTile(),
              )
            else if (resolved != null && resolved.mockPhoto != null)
              Image.network(
                resolved.mockPhoto!.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _placeholderTile(),
              )
            else
              _placeholderTile(),

            // Dim overlay
            Container(color: Colors.black.withValues(alpha: 0.35)),

            // Days remaining badge
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isUrgent
                      ? Colors.redAccent.withValues(alpha: 0.85)
                      : Colors.black.withValues(alpha: 0.6),
                  border: Border.all(
                    color: isUrgent
                        ? Colors.redAccent.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  '${daysLeft}d',
                  style: TextStyle(
                    color: isUrgent ? Colors.white : Colors.white.withValues(alpha: 0.7),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Title at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Text(
                  resolved?.title ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderTile() {
    return Container(
      color: const Color(0xFF1C1C1E),
      child: Icon(Icons.image_not_supported_rounded, color: Colors.white.withValues(alpha: 0.15), size: 28),
    );
  }

  void _showTrashItemActions(TrashItem trashItem, GalleryItem? resolved) {
    final daysLeft = trashItem.daysRemaining;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121218),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Preview row
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56, height: 56,
                    child: resolved != null && resolved.isLocal && resolved.asset != null
                        ? AssetEntityImage(
                            resolved.asset!,
                            isOriginal: false,
                            thumbnailSize: const ThumbnailSize(100, 100),
                            fit: BoxFit.cover,
                          )
                        : Container(color: const Color(0xFF1C1C1E), child: const Icon(Icons.image, color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resolved?.title ?? 'Unknown Media',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            color: daysLeft <= 3 ? Colors.redAccent : Colors.white.withValues(alpha: 0.4),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$daysLeft hari tersisa sebelum dihapus permanen',
                            style: TextStyle(
                              color: daysLeft <= 3 ? Colors.redAccent : Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _restoreItem(trashItem);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.greenAccent.withValues(alpha: 0.12),
                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restore_rounded, color: Colors.greenAccent, size: 20),
                          SizedBox(width: 8),
                          Text('Pulihkan', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _permanentDelete(trashItem);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                          SizedBox(width: 8),
                          Text('Hapus', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

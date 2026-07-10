import 'package:photo_manager/photo_manager.dart';
import '../models/photo.dart';

enum GalleryItemType { image, video }

class GalleryItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final GalleryItemType type;
  final String durationText; // For videos, e.g. "0:15"
  final AssetEntity? asset;   // If it's a native asset
  final Photo? mockPhoto;     // If it's a mock photo fallback
  final String dateText;

  GalleryItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    this.durationText = '',
    this.asset,
    this.mockPhoto,
    required this.dateText,
  });

  bool get isLocal => asset != null;
}

class MediaLoader {
  // Request native permission
  static Future<bool> requestPermission() async {
    // Request permission for images and videos
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth;
  }

  // Load local media items from the device
  static Future<List<GalleryItem>> loadLocalMedia({int count = 100}) async {
    final bool hasPermission = await requestPermission();
    if (!hasPermission) {
      return [];
    }

    try {
      // Get list of folders (albums) from device, query images and videos
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.common, // Images and Videos
        onlyAll: true,           // Usually the first folder is "Recent" or "All"
      );

      if (paths.isEmpty) return [];

      final AssetPathEntity allAlbum = paths.first;
      final List<AssetEntity> assets = await allAlbum.getAssetListRange(
        start: 0,
        end: count,
      );

      return assets.map((asset) {
        final isVideo = asset.type == AssetType.video;
        String durationStr = '';
        if (isVideo) {
          final durSeconds = asset.duration;
          final mins = durSeconds ~/ 60;
          final secs = durSeconds % 60;
          durationStr = "$mins:${secs.toString().padLeft(2, '0')}";
        }

        final createDate = asset.createDateTime;
        final dateStr = "${_monthName(createDate.month)} ${createDate.day}, ${createDate.year}";

        return GalleryItem(
          id: 'local-${asset.id}',
          title: asset.title ?? (isVideo ? 'Local Video' : 'Local Photo'),
          description: 'A native media asset loaded from your device storage.',
          category: isVideo ? 'Video' : 'Local',
          type: isVideo ? GalleryItemType.video : GalleryItemType.image,
          durationText: durationStr,
          asset: asset,
          dateText: dateStr,
        );
      }).toList();
    } catch (e) {
      print('Error loading local media: $e');
      return [];
    }
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

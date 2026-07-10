import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../utils/media_loader.dart';
import '../screens/detail_screen.dart';
import 'glass_box.dart';

class PhotoCard extends StatelessWidget {
  final GalleryItem item;
  final double height;

  const PhotoCard({
    Key? key,
    required this.item,
    required this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isVideo = item.type == GalleryItemType.video;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            reverseTransitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (context, animation, secondaryAnimation) => DetailScreen(item: item),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.0,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Hero wrapped image thumbnail (supports local and network)
              Hero(
                tag: 'hero-${item.id}',
                child: item.isLocal
                    ? AssetEntityImage(
                        item.asset!,
                        isOriginal: false,
                        thumbnailSize: const ThumbnailSize(300, 300),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF1C1C1E),
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          );
                        },
                      )
                    : Image.network(
                        item.mockPhoto!.thumbnailUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFF1C1C1E),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF1C1C1E),
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          );
                        },
                      ),
              ),

              // Video Play Badge & Duration at top right if it's a video
              if (isVideo)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GlassBox(
                    borderRadius: 12,
                    blur: 6,
                    tintColor: Colors.black.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                        if (item.durationText.isNotEmpty) ...[
                          const SizedBox(width: 2),
                          Text(
                            item.durationText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // Glass Tag Overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: GlassBox(
                  borderRadius: 0,
                  blur: 10,
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.06),
                      width: 1.0,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.favorite_border,
                        color: Colors.white.withOpacity(0.6),
                        size: 11,
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
  }
}

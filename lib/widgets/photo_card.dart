import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../utils/media_loader.dart';
import '../screens/detail_screen.dart';
import 'glass_box.dart';

class PhotoCard extends StatelessWidget {
  final GalleryItem item;
  final double height;
  final bool selectMode;
  final bool isSelected;
  final VoidCallback? onSelect;
  final VoidCallback? onLongPress;

  const PhotoCard({
    Key? key,
    required this.item,
    required this.height,
    this.selectMode = false,
    this.isSelected = false,
    this.onSelect,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isVideo = item.type == GalleryItemType.video;

    return GestureDetector(
      onTap: () {
        if (selectMode) {
          onSelect?.call();
        } else {
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
        }
      },
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: isSelected
            ? Matrix4.diagonal3Values(0.94, 0.94, 1.0)
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: isSelected
                    ? Colors.cyanAccent.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 2.0 : 1.0,
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

                // Selection overlay dim
                if (selectMode)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    color: isSelected
                        ? Colors.cyanAccent.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.25),
                  ),

                // Selection Checkbox (top-left)
                if (selectMode)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Colors.cyanAccent
                            : Colors.black.withValues(alpha: 0.4),
                        border: Border.all(
                          color: isSelected
                              ? Colors.cyanAccent
                              : Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.cyanAccent.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Color(0xFF0A0A0A), size: 16)
                          : null,
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
                      tintColor: Colors.black.withValues(alpha: 0.5),
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
                        color: Colors.white.withValues(alpha: 0.06),
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
                          color: Colors.white.withValues(alpha: 0.6),
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
      ),
    );
  }
}

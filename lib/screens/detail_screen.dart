import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';
import '../utils/media_loader.dart';
import '../storage/database.dart';
import '../widgets/glass_box.dart';

class DetailScreen extends StatefulWidget {
  final GalleryItem item;

  const DetailScreen({Key? key, required this.item}) : super(key: key);

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _isFav = false;
  bool _showMetadata = true;
  List<CustomAlbum> _albums = [];

  // Video player variables
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isInVault = false;
  bool _isVideoError = false;

  double? _latitude;
  double? _longitude;
  bool _isLoadingCoords = true;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
    _loadAlbums();
    _checkVaultStatus();
    _loadCoordinates();
    if (widget.item.type == GalleryItemType.video && widget.item.isLocal) {
      _initVideoPlayer();
    }
  }

  Future<void> _loadCoordinates() async {
    double? lat;
    double? lng;

    if (widget.item.isLocal) {
      try {
        final loc = await widget.item.asset!.latlngAsync();
        final locLat = loc.latitude;
        final locLng = loc.longitude;
        if (locLat != null && locLng != null && (locLat != 0.0 || locLng != 0.0)) {
          lat = locLat;
          lng = locLng;
        }
      } catch (e) {
        // Fallback or ignore
      }
    } else {
      final exifLoc = widget.item.mockPhoto?.exif.location.toLowerCase() ?? '';
      if (exifLoc.contains('tokyo') || exifLoc.contains('japan')) {
        lat = 35.6762;
        lng = 139.6503;
      } else if (exifLoc.contains('paris') || exifLoc.contains('france')) {
        lat = 48.8566;
        lng = 2.3522;
      } else if (exifLoc.contains('iceland')) {
        lat = 64.9631;
        lng = -19.0208;
      } else if (exifLoc.contains('kyoto')) {
        lat = 35.0116;
        lng = 135.7681;
      } else if (exifLoc.contains('bali') || exifLoc.contains('indonesia')) {
        lat = -8.4095;
        lng = 115.1889;
      }
    }

    if (mounted) {
      setState(() {
        _latitude = lat;
        _longitude = lng;
        _isLoadingCoords = false;
      });
    }
  }

  Future<void> _openMaps() async {
    if (_latitude == null || _longitude == null) return;
    
    final googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$_latitude,$_longitude");
    final appleMapsUrl = Uri.parse("maps://?q=$_latitude,$_longitude");

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(appleMapsUrl)) {
        await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open map application.')),
        );
      }
    } catch (e) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideoPlayer() async {
    try {
      final File? file = await widget.item.asset!.file;
      if (file != null) {
        _videoController = VideoPlayerController.file(file)
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                _isVideoInitialized = true;
              });
              // Auto-play the video
              _videoController!.play();
              _videoController!.setLooping(true);
            }
          }).catchError((err) {
            print("Video init error: $err");
            if (mounted) {
              setState(() {
                _isVideoError = true;
              });
            }
          });
      } else {
        setState(() {
          _isVideoError = true;
        });
      }
    } catch (e) {
      print("Error loading video file: $e");
      setState(() {
        _isVideoError = true;
      });
    }
  }

  Future<void> _checkFavorite() async {
    final fav = await DatabaseHelper.isFavorite(widget.item.id);
    if (mounted) {
      setState(() {
        _isFav = fav;
      });
    }
  }

  Future<void> _loadAlbums() async {
    final albs = await DatabaseHelper.getAlbums();
    if (mounted) {
      setState(() {
        _albums = albs;
      });
    }
  }

  Future<void> _checkVaultStatus() async {
    final locked = await DatabaseHelper.isInVault(widget.item.id);
    if (mounted) {
      setState(() {
        _isInVault = locked;
      });
    }
  }

  Future<void> _toggleVaultStatus() async {
    final updated = await DatabaseHelper.toggleVaultItem(widget.item.id);
    setState(() {
      _isInVault = updated.contains(widget.item.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isInVault 
            ? 'Media locked in Private Vault!' 
            : 'Media unlocked and restored to public gallery!'),
        backgroundColor: _isInVault ? Colors.blue.shade600 : Colors.green.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final updated = await DatabaseHelper.toggleFavorite(widget.item.id);
    setState(() {
      _isFav = updated.contains(widget.item.id);
    });
  }

  bool _isSharing = false;

  Future<void> _shareMedia() async {
    if (_isSharing) return;
    setState(() { _isSharing = true; });

    try {
      if (widget.item.isLocal && widget.item.asset != null) {
        // Get the actual file from the device
        final File? file = await widget.item.asset!.file;
        if (file != null) {
          final xFile = XFile(file.path);
          final result = await SharePlus.instance.share(
            ShareParams(
              files: [xFile],
              title: widget.item.title,
            ),
          );
          if (mounted && result.status == ShareResultStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.cyanAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Media berhasil dibagikan!', style: TextStyle(color: Colors.white)),
                  ],
                ),
                backgroundColor: const Color(0xFF1A1A2E),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            );
          }
        }
      } else if (widget.item.mockPhoto != null) {
        // Share the URL for network images
        await SharePlus.instance.share(
          ShareParams(
            text: '${widget.item.title}\n${widget.item.mockPhoto!.url}',
            title: widget.item.title,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membagikan: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSharing = false; });
      }
    }
  }

  void _showAddToAlbumSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassBox(
          borderRadius: 24,
          blur: 25,
          tintColor: Colors.black.withOpacity(0.6),
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.12),
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'Add to Album',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: _albums.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No albums found',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _albums.length,
                        itemBuilder: (context, index) {
                          final album = _albums[index];
                          final alreadyAdded = album.photoIds.contains(widget.item.id);

                          return ListTile(
                            leading: Icon(
                              Icons.folder_rounded,
                              color: Colors.blue.shade400,
                            ),
                            title: Text(
                              album.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${album.photoIds.length} photos',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                              ),
                            ),
                            trailing: Icon(
                              alreadyAdded ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                              color: alreadyAdded ? Colors.green : Colors.white.withOpacity(0.4),
                            ),
                            onTap: alreadyAdded
                                ? null
                                : () async {
                                    await DatabaseHelper.addPhotoToAlbum(album.id, widget.item.id);
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added to ${album.name}!'),
                                        backgroundColor: Colors.blue.shade600,
                                      ),
                                    );
                                  },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isVideo = widget.item.type == GalleryItemType.video;

    // Resolve EXIF details
    String cameraText = 'Local Media';
    String lensText = 'System File';
    String exposureText = 'Original';
    String locationText = 'Local Storage';

    if (widget.item.isLocal) {
      final asset = widget.item.asset!;
      exposureText = '${asset.width} x ${asset.height}';
      locationText = (asset.latitude != null && asset.longitude != null) 
          ? '${asset.latitude!.toStringAsFixed(3)}, ${asset.longitude!.toStringAsFixed(3)}'
          : 'Local Album';
      cameraText = isVideo ? 'Native Video' : 'Native Photo';
      lensText = asset.mimeType ?? 'Unknown MIME';
    } else {
      final mock = widget.item.mockPhoto!;
      cameraText = mock.exif.camera;
      lensText = mock.exif.lens;
      exposureText = '${mock.exif.shutterSpeed} @ ${mock.exif.aperture}';
      locationText = mock.exif.location;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient Glow Background (Uses local asset or network image)
          if (widget.item.isLocal)
            AssetEntityImage(
              widget.item.asset!,
              isOriginal: false,
              fit: BoxFit.cover,
              errorBuilder: (c, o, s) => Container(color: Colors.black),
            )
          else
            Image.network(
              widget.item.mockPhoto!.url,
              fit: BoxFit.cover,
              errorBuilder: (c, o, s) => Container(color: Colors.black),
            ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(
              color: Colors.black.withOpacity(0.55),
            ),
          ),

          // Main Media Viewer
          Center(
            child: isVideo
                ? _buildVideoPlayerWidget(size)
                : InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Hero(
                      tag: 'hero-${widget.item.id}',
                      child: widget.item.isLocal
                          ? AssetEntityImage(
                              widget.item.asset!,
                              isOriginal: true,
                              fit: BoxFit.contain,
                              width: size.width,
                              height: size.height * 0.7,
                              errorBuilder: (c, o, s) => const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 64,
                              ),
                            )
                          : Image.network(
                              widget.item.mockPhoto!.url,
                              fit: BoxFit.contain,
                              width: size.width,
                              height: size.height * 0.7,
                              errorBuilder: (c, o, s) => const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 64,
                              ),
                            ),
                    ),
                  ),
          ),

          // Top Action Buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: GlassBox(
                    width: 40,
                    height: 40,
                    borderRadius: 20,
                    blur: 10,
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                Row(
                  children: [
                    // Share Button
                    GestureDetector(
                      onTap: _shareMedia,
                      child: GlassBox(
                        width: 40,
                        height: 40,
                        borderRadius: 20,
                        blur: 10,
                        tintColor: Colors.cyanAccent.withValues(alpha: 0.08),
                        child: _isSharing
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.cyanAccent,
                                ),
                              )
                            : const Icon(
                                Icons.share_rounded,
                                color: Colors.cyanAccent,
                                size: 18,
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _toggleVaultStatus,
                      child: GlassBox(
                        width: 40,
                        height: 40,
                        borderRadius: 20,
                        blur: 10,
                        child: Icon(
                          _isInVault ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                          color: _isInVault ? Colors.blue.shade400 : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _showAddToAlbumSheet,
                      child: GlassBox(
                        width: 40,
                        height: 40,
                        borderRadius: 20,
                        blur: 10,
                        child: const Icon(
                          Icons.folder_open_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _toggleFavorite,
                      child: GlassBox(
                        width: 40,
                        height: 40,
                        borderRadius: 20,
                        blur: 10,
                        child: Icon(
                          _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _isFav ? Colors.red : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom EXIF Info Sheet
          if (_showMetadata)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GlassBox(
                borderRadius: 24,
                blur: 20,
                tintColor: Colors.black.withOpacity(0.55),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.12),
                    width: 1.0,
                  ),
                ),
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 16.0,
                  bottom: MediaQuery.of(context).padding.bottom + 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle and Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue.shade400.withOpacity(0.2),
                                ),
                                child: Icon(
                                  isVideo ? Icons.play_circle_fill_rounded : Icons.photo_size_select_actual_rounded,
                                  color: Colors.blue.shade400,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.item.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      widget.item.dateText,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          onPressed: () {
                            setState(() {
                              _showMetadata = false;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.item.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // EXIF grid details
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 3.2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        _buildExifTile(Icons.camera_rounded, 'Camera', cameraText),
                        _buildExifTile(Icons.camera_roll_rounded, 'MIME/Lens', lensText),
                        _buildExifTile(Icons.shutter_speed_rounded, 'Resolution', exposureText),
                        _buildExifTile(Icons.location_on_rounded, 'Location', locationText),
                      ],
                    ),
                    if (_latitude != null && _longitude != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.08),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'LOCATION MAP',
                        style: TextStyle(
                          color: Colors.white30,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _openMaps,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 110,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                                width: 1.0,
                              ),
                            ),
                            child: Stack(
                              children: [
                                CustomPaint(
                                  size: const Size(double.infinity, 110),
                                  painter: MapGridPainter(),
                                ),
                                Positioned(
                                  left: 0, right: 0, top: 0, bottom: 0,
                                  child: Center(
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.redAccent.withOpacity(0.4),
                                            blurRadius: 20,
                                            spreadRadius: 6,
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        color: Colors.redAccent,
                                        size: 26,
                                      ),
                                      Container(
                                        width: 8,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: Colors.black38,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: GlassBox(
                                    borderRadius: 0,
                                    blur: 5,
                                    tintColor: Colors.black.withOpacity(0.4),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              'Open in Maps',
                                              style: TextStyle(
                                                color: Colors.blue.shade300,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.open_in_new_rounded,
                                              color: Colors.blue.shade300,
                                              size: 11,
                                            ),
                                          ],
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
                    ],
                  ],
                ),
              ),
            ),

          // Mini bubble button to reopen Info sheet if closed
          if (!_showMetadata)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              child: Container(
                width: size.width,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showMetadata = true;
                    });
                  },
                  child: GlassBox(
                    borderRadius: 24,
                    blur: 10,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Show Info',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerWidget(Size size) {
    if (_isVideoError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.redAccent.shade400, size: 48),
          const SizedBox(height: 12),
          const Text('Error loading video', style: TextStyle(color: Colors.white70)),
        ],
      );
    }

    if (!_isVideoInitialized) {
      return const CircularProgressIndicator(color: Colors.blue);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_videoController!.value.isPlaying) {
            _videoController!.pause();
          } else {
            _videoController!.play();
          }
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Actual Video player
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),

          // Play/Pause Overlay Indicator
          if (!_videoController!.value.isPlaying)
            GlassBox(
              width: 64,
              height: 64,
              borderRadius: 32,
              blur: 5,
              tintColor: Colors.black.withOpacity(0.3),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExifTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade400, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw horizontal grid lines
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
    // Draw vertical grid lines
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    // Draw some stylized diagonal "streets"
    final streetPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, 30), Offset(size.width, 90), streetPaint);
    canvas.drawLine(Offset(size.width * 0.2, 0), Offset(size.width * 0.8, size.height), streetPaint);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.2), streetPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


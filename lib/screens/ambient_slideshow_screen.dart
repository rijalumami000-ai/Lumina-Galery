import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../utils/media_loader.dart';
import '../widgets/glass_box.dart';

class AmbientSlideshowScreen extends StatefulWidget {
  final List<GalleryItem> items;
  final int startIndex;

  const AmbientSlideshowScreen({
    Key? key,
    required this.items,
    this.startIndex = 0,
  }) : super(key: key);

  @override
  _AmbientSlideshowScreenState createState() => _AmbientSlideshowScreenState();
}

class _AmbientSlideshowScreenState extends State<AmbientSlideshowScreen> with TickerProviderStateMixin {
  late int _currentIndex;
  bool _isPlaying = true;
  int _slideSpeedSeconds = 5;
  Timer? _timer;
  
  // Animation controller for the Ken Burns zoom effect
  late AnimationController _kenBurnsController;
  late Animation<double> _scaleAnimation;
  late Animation<Alignment> _alignmentAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    
    _kenBurnsController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _slideSpeedSeconds),
    );

    _setupKenBurnsAnimations();
    _startSlideshowTimer();
  }

  void _setupKenBurnsAnimations() {
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _kenBurnsController, curve: Curves.linear),
    );

    // Randomize movement alignment to make zoom feel organic
    final alignments = [
      Alignment.center,
      Alignment.topCenter,
      Alignment.bottomCenter,
      Alignment.centerLeft,
      Alignment.centerRight,
    ];
    final selectedAlignment = alignments[_currentIndex % alignments.length];
    
    _alignmentAnimation = AlignmentTween(
      begin: selectedAlignment,
      end: Alignment(
        selectedAlignment.x * 0.9,
        selectedAlignment.y * 0.9,
      ),
    ).animate(CurvedAnimation(parent: _kenBurnsController, curve: Curves.linear));

    _kenBurnsController.forward(from: 0.0);
  }

  void _startSlideshowTimer() {
    _timer?.cancel();
    if (_isPlaying && widget.items.isNotEmpty) {
      _timer = Timer.periodic(Duration(seconds: _slideSpeedSeconds), (timer) {
        _nextSlide();
      });
    }
  }

  void _nextSlide() {
    if (widget.items.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.items.length;
      _setupKenBurnsAnimations();
    });
  }

  void _prevSlide() {
    if (widget.items.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + widget.items.length) % widget.items.length;
      _setupKenBurnsAnimations();
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _kenBurnsController.forward();
        _startSlideshowTimer();
      } else {
        _kenBurnsController.stop();
        _timer?.cancel();
      }
    });
  }

  void _updateSpeed(int seconds) {
    setState(() {
      _slideSpeedSeconds = seconds;
      _kenBurnsController.duration = Duration(seconds: seconds);
      if (_isPlaying) {
        _kenBurnsController.forward(from: _kenBurnsController.value);
        _startSlideshowTimer();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _kenBurnsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No media items to display', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final activeItem = widget.items[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. BACKGROUND AMBIENT GLOW
          // Blurred backdrop of the active image to create a rich ambient visual experience
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1000),
            child: KeyedSubtree(
              key: ValueKey<String>('ambient_${activeItem.id}'),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  activeItem.isLocal
                      ? AssetEntityImage(
                          activeItem.asset!,
                          isOriginal: false,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          activeItem.mockPhoto!.thumbnailUrl,
                          fit: BoxFit.cover,
                        ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Container(
                      color: Colors.black.withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. ACTIVE SLIDE WITH KEN BURNS EFFECT
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1000),
              layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                return Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: KeyedSubtree(
                key: ValueKey<String>('slide_${activeItem.id}'),
                child: AnimatedBuilder(
                  animation: _kenBurnsController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      alignment: _alignmentAnimation.value,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.9,
                          maxHeight: MediaQuery.of(context).size.height * 0.7,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: activeItem.isLocal
                              ? AssetEntityImage(
                                  activeItem.asset!,
                                  isOriginal: true,
                                  fit: BoxFit.contain,
                                )
                              : Image.network(
                                  activeItem.mockPhoto!.url,
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 3. OVERLAY CONTROL INTERFACES
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top control bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close Button
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: GlassBox(
                          width: 40,
                          height: 40,
                          borderRadius: 20,
                          blur: 10,
                          child: const Icon(Icons.close_rounded, color: Colors.white),
                        ),
                      ),
                      
                      // Title
                      Column(
                        children: [
                          const Text(
                            'AMBIENT SLIDESHOW',
                            style: TextStyle(
                              color: Colors.white30,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeItem.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      
                      // Speed indicator
                      PopupMenuButton<int>(
                        onSelected: _updateSpeed,
                        color: const Color(0xFF1C1C1E),
                        child: GlassBox(
                          width: 50,
                          height: 40,
                          borderRadius: 20,
                          blur: 10,
                          child: Center(
                            child: Text(
                              '${_slideSpeedSeconds}s',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 3, child: Text('3 seconds', style: TextStyle(color: Colors.white))),
                          const PopupMenuItem(value: 5, child: Text('5 seconds', style: TextStyle(color: Colors.white))),
                          const PopupMenuItem(value: 8, child: Text('8 seconds', style: TextStyle(color: Colors.white))),
                        ],
                      ),
                    ],
                  ),
                ),

                // Bottom control bar
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GlassBox(
                        borderRadius: 30,
                        blur: 15,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Previous button
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                              onPressed: _prevSlide,
                            ),
                            const SizedBox(width: 8),
                            
                            // Play/Pause button
                            GestureDetector(
                              onTap: _togglePlayPause,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue.shade500,
                                ),
                                child: Icon(
                                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            
                            // Next button
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                              onPressed: _nextSlide,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

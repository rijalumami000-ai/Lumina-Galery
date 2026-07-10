import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/photo.dart';
import '../utils/mock_data.dart';
import '../widgets/glass_box.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({Key? key}) : super(key: key);

  @override
  _StudioScreenState createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  late Photo _selectedPhoto;
  double _brightness = 1.0; // 0.3 to 1.7
  double _saturation = 1.0; // 0.0 to 2.0
  double _blur = 0.0;       // 0.0 to 15.0
  double _sepia = 0.0;      // 0.0 to 1.0
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedPhoto = MOCK_PHOTOS.first;
  }

  void _resetFilters() {
    setState(() {
      _brightness = 1.0;
      _saturation = 1.0;
      _blur = 0.0;
      _sepia = 0.0;
    });
  }

  void _exportPhoto() {
    setState(() {
      _isSaving = true;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            title: const Text('Success', style: TextStyle(color: Colors.white)),
            content: const Text(
              'Lumina Photo Studio: Photo edits saved to your gallery with premium configurations!',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Great', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        );
      }
    });
  }

  // Helper matrix generators for nested ColorFiltered widgets
  List<double> _getBrightnessMatrix() {
    final b = _brightness;
    return [
      b, 0, 0, 0, 0,
      0, b, 0, 0, 0,
      0, 0, b, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _getSaturationMatrix() {
    final s = _saturation;
    final invSat = 1.0 - s;
    final rWeight = 0.213 * invSat;
    final gWeight = 0.715 * invSat;
    final bWeight = 0.072 * invSat;
    return [
      rWeight + s, gWeight, bWeight, 0, 0,
      rWeight, gWeight + s, bWeight, 0, 0,
      rWeight, gWeight, bWeight + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  List<double> _getSepiaMatrix() {
    final s = _sepia;
    return [
      0.393 + 0.607 * (1 - s), 0.769 - 0.769 * (1 - s), 0.189 - 0.189 * (1 - s), 0, 0,
      0.349 - 0.349 * (1 - s), 0.686 + 0.314 * (1 - s), 0.168 - 0.168 * (1 - s), 0, 0,
      0.272 - 0.272 * (1 - s), 0.534 - 0.534 * (1 - s), 0.131 + 0.869 * (1 - s), 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Photo Studio',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fine-tune filters and light settings',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _resetFilters,
                      child: GlassBox(
                        width: 36,
                        height: 36,
                        borderRadius: 18,
                        blur: 5,
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Horizontal Selector list
              SizedBox(
                height: 50,
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  itemCount: MOCK_PHOTOS.length,
                  itemBuilder: (context, index) {
                    final photo = MOCK_PHOTOS[index];
                    final isSelected = photo.id == _selectedPhoto.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPhoto = photo;
                          _resetFilters();
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12.0),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? Colors.blue.shade400 : Colors.transparent,
                            width: 2,
                          ),
                          image: DecorationImage(
                            image: NetworkImage(photo.thumbnailUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Image Canvas
              Expanded(
                child: Center(
                  child: GlassBox(
                    borderRadius: 24,
                    blur: 5,
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: size.width - 64,
                          maxHeight: size.height * 0.35,
                        ),
                        color: const Color(0xFF1C1C1E),
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
                          child: ColorFiltered(
                            colorFilter: ColorFilter.matrix(_getBrightnessMatrix()),
                            child: ColorFiltered(
                              colorFilter: ColorFilter.matrix(_getSaturationMatrix()),
                              child: ColorFiltered(
                                colorFilter: ColorFilter.matrix(_getSepiaMatrix()),
                                child: Image.network(
                                  _selectedPhoto.url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, o, s) => const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Adjustment Panel
              GlassBox(
                borderRadius: 24,
                blur: 15,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSlider(
                      label: 'Brightness',
                      icon: Icons.light_mode_rounded,
                      value: _brightness,
                      min: 0.3,
                      max: 1.7,
                      onChanged: (val) => setState(() => _brightness = val),
                    ),
                    const SizedBox(height: 12),
                    _buildSlider(
                      label: 'Saturate',
                      icon: Icons.palette_rounded,
                      value: _saturation,
                      min: 0.0,
                      max: 2.0,
                      onChanged: (val) => setState(() => _saturation = val),
                    ),
                    const SizedBox(height: 12),
                    _buildSlider(
                      label: 'Glass Blur',
                      icon: Icons.blur_on_rounded,
                      value: _blur,
                      min: 0.0,
                      max: 15.0,
                      onChanged: (val) => setState(() => _blur = val),
                    ),
                    const SizedBox(height: 12),
                    _buildSlider(
                      label: 'Classic Sepia',
                      icon: Icons.filter_b_and_w_rounded,
                      value: _sepia,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) => setState(() => _sepia = val),
                    ),
                    const SizedBox(height: 20),
                    
                    // Action Button
                    GestureDetector(
                      onTap: _isSaving ? null : _exportPhoto,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade500,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            _isSaving ? 'Rendering...' : 'Export Edited Photo',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 110), // floating tab bar spacer
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.blue.shade400, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    value.toStringAsFixed(1),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3.0,
                  activeTrackColor: Colors.blue.shade400,
                  inactiveTrackColor: Colors.white.withOpacity(0.1),
                  thumbColor: Colors.white,
                  overlayColor: Colors.blue.withOpacity(0.2),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

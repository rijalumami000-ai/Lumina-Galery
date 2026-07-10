import 'package:flutter/material.dart';
import 'glass_box.dart';

class LuminaTabBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const LuminaTabBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Container(
      padding: const EdgeInsets.only(bottom: 24.0),
      alignment: Alignment.bottomCenter,
      child: GlassBox(
        width: width * 0.88,
        height: 64,
        blur: 18,
        borderRadius: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTabItem(context, 0, Icons.home_rounded, 'Home'),
            _buildTabItem(context, 1, Icons.explore_rounded, 'Explore'),
            _buildTabItem(context, 2, Icons.favorite_rounded, 'Library'),
            _buildTabItem(context, 3, Icons.tune_rounded, 'Studio'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    final activeColor = Colors.blue.shade400;
    final inactiveColor = Colors.white.withOpacity(0.55);

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 8.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

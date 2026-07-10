import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/library_screen.dart';
import 'screens/studio_screen.dart';
import 'widgets/tab_bar.dart';

void main() {
  runApp(const LuminaGalleryApp());
}

class LuminaGalleryApp extends StatelessWidget {
  const LuminaGalleryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumina Gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto', // Modern standard system font
        scaffoldBackgroundColor: const Color(0xFF0F0F11),
      ),
      home: const MainNavigationHub(),
    );
  }
}

class MainNavigationHub extends StatefulWidget {
  const MainNavigationHub({Key? key}) : super(key: key);

  @override
  _MainNavigationHubState createState() => _MainNavigationHubState();
}

class _MainNavigationHubState extends State<MainNavigationHub> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ExploreScreen(),
    LibraryScreen(),
    StudioScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // IndexedStack preserves state of scrollbars and inputs of each screen
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          
          // Reusable Floating Glassmorphic tab bar overlay
          LuminaTabBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        ],
      ),
    );
  }
}

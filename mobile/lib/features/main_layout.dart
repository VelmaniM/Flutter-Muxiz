import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/components/glass_bottom_bar.dart';
import '../shared/components/mini_player.dart';
import 'home/presentation/home_screen.dart';
import 'search/presentation/search_screen.dart';
import 'library/presentation/library_screen.dart';
import 'upload/presentation/upload_screen.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class MainLayout extends ConsumerWidget {
  const MainLayout({super.key});

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    UploadScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(selectedTabProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Main Screen Pages
          IndexedStack(
            index: currentIndex,
            children: _screens,
          ),

          // Pinned Floating Mini Player & Frosted Bottom Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                GlassBottomBar(
                  currentIndex: currentIndex,
                  onTabSelected: (index) {
                    ref.read(selectedTabProvider.notifier).state = index;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

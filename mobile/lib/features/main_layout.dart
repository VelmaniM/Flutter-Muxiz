import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/components/glass_bottom_bar.dart';
import '../shared/components/mini_player.dart';
import 'home/presentation/home_screen.dart';
import 'search/presentation/search_screen.dart';
import 'library/presentation/library_screen.dart';

import '../core/audio/audio_manager.dart';
import '../core/storage/local_storage.dart';

final selectedTabProvider = StateNotifierProvider<SelectedTabNotifier, int>((ref) {
  return SelectedTabNotifier();
});

class SelectedTabNotifier extends StateNotifier<int> {
  SelectedTabNotifier() : super(LocalStorageService.getLastActiveTab());

  void setTab(int index) {
    state = index;
    LocalStorageService.saveLastActiveTab(index);
  }
}

final homeResetTriggerProvider = StateProvider<int>((ref) => 0);

class MainLayout extends ConsumerWidget {
  const MainLayout({super.key});

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(selectedTabProvider);

    // ⚡ FIRST-TIME ONLY: Auto redirect to Home screen when user plays their first song
    ref.listen(playerStateProvider.select((s) => s.currentSong?.id), (previous, next) {
      if (next != null && next != previous) {
        if (!LocalStorageService.hasCompletedFirstPlay()) {
          LocalStorageService.markFirstPlayCompleted();
          ref.read(selectedTabProvider.notifier).setTab(0);
        }
      }
    });

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
                    if (index == 0 && currentIndex == 0) {
                      // Tap Home again -> reset filter to "All" and scroll to top!
                      ref.read(homeResetTriggerProvider.notifier).state++;
                    } else {
                      ref.read(selectedTabProvider.notifier).setTab(index);
                    }
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

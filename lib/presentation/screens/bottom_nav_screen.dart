import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/presentation/screens/home_screen.dart';
import 'package:startup_20/providers/bottom_nav_provider.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';

class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int selected = 0;
  final controller = PageController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<BottomNavProvider>(context);

    return Scaffold(
      extendBody: true,
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 400), // slower animation
        height: navProvider.isVisible ? kBottomNavigationBarHeight : 0,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Wrap(
          children: [
            StylishBottomBar(
              option: AnimatedBarOptions(),
              items: [
                BottomBarItem(
                  icon: const Icon(Icons.house_outlined),
                  selectedIcon: const Icon(Icons.house_rounded),
                  selectedColor: AppColors.selectedColor,
                  unSelectedColor: AppColors.unselectedColor,
                  title: const Text('Home'),
                ),
                BottomBarItem(
                  icon: const Icon(Icons.widgets_outlined),
                  selectedIcon: const Icon(Icons.widgets),
                  selectedColor: AppColors.selectedColor,
                  unSelectedColor: AppColors.unselectedColor,
                  title: const Text('Categories'),
                ),
                BottomBarItem(
                  icon: const Icon(Icons.chat_bubble_outline),
                  selectedIcon: const Icon(Icons.chat_bubble),
                  badge: const Text('9+'),
                  showBadge: true,
                  badgeColor: AppColors.badgeColor,
                  selectedColor: AppColors.selectedColor,
                  unSelectedColor: AppColors.unselectedColor,
                  title: const Text('Chat'),
                ),
                BottomBarItem(
                  icon: const Icon(Icons.add_circle),
                  selectedIcon: const Icon(Icons.add_circle_outline),
                  selectedColor: AppColors.selectedColor,
                  unSelectedColor: AppColors.unselectedColor,
                  title: const Text('Contribute'),
                ),
              ],
              hasNotch: true,
              currentIndex: selected,
              onTap: (index) {
                if (index == selected) return;
                controller.jumpToPage(index);
                setState(() {
                  selected = index;
                });
              },
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      body: SafeArea(
        child: PageView(
          controller: controller,
          children: const [
            HomeScreen(),
            Center(child: Text('Categories')),
            Center(child: Text('Chat')),
          ],
        ),
      ),
    );
  }
}

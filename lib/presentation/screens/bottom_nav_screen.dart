import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/screens/category_screen.dart';
import 'package:startup_20/presentation/screens/conversation/chat_screen.dart';
import 'package:startup_20/presentation/screens/contribute_screen.dart';
import 'package:startup_20/presentation/screens/home_screen.dart';
import 'package:startup_20/presentation/screens/logins/signin_screen.dart';
import 'package:startup_20/providers/auth_provider.dart';
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
    final authProvider = Provider.of<AppAuthProvider>(context);


    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.THEME_COLOR, // solid red background
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        bottomNavigationBar: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          height: navProvider.isVisible ? kBottomNavigationBarHeight : 0,
          decoration: BoxDecoration(
            color: AppColors.WHITE,
            boxShadow: [
              BoxShadow(
                color: AppColors.BLACK.withOpacity(0.1),
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
                    selectedColor: AppColors.THEME_COLOR,
                    unSelectedColor: AppColors.GREY,
                    title: const Text('Home'),
                  ),
                  BottomBarItem(
                    icon: const Icon(Icons.widgets_outlined),
                    selectedIcon: const Icon(Icons.widgets),
                    selectedColor: AppColors.THEME_COLOR,
                    unSelectedColor: AppColors.GREY,
                    title: const Text('Categories'),
                  ),
                  BottomBarItem(
                    icon: const Icon(Icons.chat_bubble_outline),
                    selectedIcon: const Icon(Icons.chat_bubble),
                    badge: const Text('9+'),
                    showBadge: true,
                    badgeColor: AppColors.THEME_COLOR,
                    selectedColor: AppColors.THEME_COLOR,
                    unSelectedColor: AppColors.GREY,
                    title: const Text('Chat'),
                  ),
                  BottomBarItem(
                    icon: const Icon(Icons.add_circle_outline),
                    selectedIcon: const Icon(Icons.add_circle),
                    selectedColor: AppColors.THEME_COLOR,
                    unSelectedColor: AppColors.GREY,
                    title: const Text('Contribute'),
                  ),
                ],
                hasNotch: true,
                currentIndex: navProvider.currentIndex,
                onTap: (index) {
                  if (index == navProvider.currentIndex) return;
                  navProvider.setIndex(index); // ✅ use provider
                },
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: IndexedStack(
            index: navProvider.currentIndex,
            children: [
              HomeScreen(),
              CategoryScreen(),

              authProvider.isAnonymous
                  ? SignInScreen()
                  : ChatScreen(
                    currentUserId: FirebaseAuth.instance.currentUser!.uid,
                  ),
              authProvider.isAnonymous ? SignInScreen() : ContributionScreen(),
            ],
          ),
        ),
      ),
    );
  }
}

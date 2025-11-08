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
import 'package:startup_20/providers/chat_provider.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';

class BottomNavScreen extends StatefulWidget {
  final int initialIndex;
  const BottomNavScreen({this.initialIndex = 0, Key? key}) : super(key: key);

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen>
    with WidgetsBindingObserver {
  final controller = PageController();

  DateTime? lastBackPressed; // 👈 For tracking double back press timing

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CommonMethods.onAppStart();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      CommonMethods.onAppClose();
    } else if (state == AppLifecycleState.resumed) {
      CommonMethods.onAppStart();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    CommonMethods.onAppClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<BottomNavProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return WillPopScope(
      // 👈 Wrap Scaffold with WillPopScope
      onWillPop: () async {
        if (navProvider.currentIndex != 0) {
          // 👈 If not on Home, go to Home
          navProvider.setIndex(0);
          return false;
        }

        // 👇 Handle double back press to exit
        final now = DateTime.now();
        if (lastBackPressed == null ||
            now.difference(lastBackPressed!) > const Duration(seconds: 2)) {
          lastBackPressed = now;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Press again to exit",
                textAlign: TextAlign.center,
              ),

              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 100, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: AppColors.BLACK_54,
            ),
          );
          return false;
        }
        CommonMethods.onAppClose();
        return true; // 👈 Exit app on second back press
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.THEME_COLOR,
          toolbarHeight: 8,
        ),
        bottomNavigationBar: SafeArea(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            height: navProvider.isVisible ? kBottomNavigationBarHeight : 0,
            decoration: BoxDecoration(
              color: AppColors.WHITE,
              boxShadow: [
                BoxShadow(
                  color: AppColors.BLACK.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
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
                      badge:
                          chatProvider.unreadCount > 0
                              ? Text(
                                chatProvider.unreadCount > 9
                                    ? '9+'
                                    : chatProvider.unreadCount.toString(),
                                style: const TextStyle(
                                  color: AppColors.WHITE,
                                  fontSize: 10,
                                ),
                              )
                              : null,
                      showBadge: chatProvider.unreadCount > 0,
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
                    navProvider.setIndex(index);
                  },
                ),
              ],
            ),
          ),
        ),
        body: IndexedStack(
          index: navProvider.currentIndex,
          children: [
            HomeScreen(),
            CategoryScreen(),
            AppAuthProvider.isAnonymousUser()
                ? SignInScreen(skip: false)
                : ChatScreen(),
            AppAuthProvider.isAnonymousUser()
                ? SignInScreen(skip: false)
                : ContributionScreen(),
          ],
        ),
      ),
    );
  }
}

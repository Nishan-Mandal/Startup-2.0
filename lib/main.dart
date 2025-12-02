import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/core/services/notification_service.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/screens/conversation/chat_screen.dart';
import 'package:startup_20/presentation/screens/home_screen.dart';
import 'package:startup_20/presentation/screens/listing_detail_screen.dart';
import 'package:startup_20/presentation/screens/logins/signin_screen.dart';
import 'package:startup_20/presentation/screens/notification_screen.dart';
import 'package:startup_20/presentation/screens/onboarding_screen.dart';
import 'package:startup_20/providers/chat_provider.dart';

import 'providers/auth_provider.dart';
import 'providers/bottom_nav_provider.dart';
import 'presentation/screens/bottom_nav_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  await NotificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => BottomNavProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],

      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<AppAuthProvider>().firebaseUser;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Findon',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.THEME_COLOR),
      ),
      navigatorKey: navigatorKey,
      routes: {
        '/notifications': (context) => const NotificationsScreen(),
        '/chatScreen': (context) => const BottomNavScreen(initialIndex: 3),

        // const ListingDetailScreen(listing: listing, similarListings: similarListings),
      },

      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');
        if (uri.pathSegments.isNotEmpty &&
            uri.pathSegments.length == 2 &&
            uri.pathSegments.first == 'listing') {
          final listingId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder:
                (context) => FutureBuilder<DocumentSnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('listings')
                          .doc(listingId)
                          .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Scaffold(
                        body: Center(child: Text("Listing not found")),
                      );
                    }

                    final listing = Listing.fromJson(
                      snapshot.data!.data() as Map<String, dynamic>,
                    );

                    return ListingDetailScreen(
                      listing: listing,
                      similarListings: [],
                    );
                  },
                ),
          );
        }

        // fallback
        return MaterialPageRoute(
          builder:
              (_) =>
                  AppAuthProvider.isAnonymousUser()
                      ? SignInScreen(skip: false)
                      : HomeScreen(),
        );
      },

      home:
          firebaseUser == null
              ? const OnboardingScreen()
              : const BottomNavScreen(),
    );
  }
}

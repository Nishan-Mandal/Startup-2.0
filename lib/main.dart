import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/presentation/screens/bottom_nav_screen.dart';
import 'package:startup_20/presentation/screens/logins/signin_screen.dart';
import 'package:startup_20/presentation/screens/logins/signup_screen.dart';
import 'package:startup_20/providers/bottom_nav_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: 
          FirebaseAuth.instance.currentUser == null
              ? SignInScreen()
              : ChangeNotifierProvider(
                create: (_) => BottomNavProvider(),
                child: const BottomNavScreen(),
              ),
    );
  }
}

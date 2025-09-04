import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/presentation/screens/bottom_nav_screen.dart';
import 'package:startup_20/providers/bottom_nav_provider.dart';

void main() {
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
      home: ChangeNotifierProvider(
        create: (_) => BottomNavProvider(),
        child: const BottomNavScreen(),
      ),
    );
  }
}

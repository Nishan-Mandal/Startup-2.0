import 'package:flutter/material.dart';

class BottomNavProvider extends ChangeNotifier {
  int currentIndex = 0;
  bool isVisible = true;

  void setIndex(int index) {
    currentIndex = index;
    notifyListeners();
  }
}

import 'package:flutter/material.dart';

class BottomNavProvider extends ChangeNotifier {
  bool _isVisible = true;

  bool get isVisible => _isVisible;

  void showNavBar() {
    if (!_isVisible) {
      _isVisible = true;
      notifyListeners();
    }
  }

  void hideNavBar() {
    if (_isVisible) {
      _isVisible = false;
      notifyListeners();
    }
  }
}

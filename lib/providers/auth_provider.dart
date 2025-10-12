import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppAuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  User? get user => _user;

  bool get isLoggedIn => _user != null;
  bool get isAnonymous => _user?.phoneNumber == null;

  AppAuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
  }
}

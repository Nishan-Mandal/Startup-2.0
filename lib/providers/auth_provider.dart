import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppAuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  User? get user => _user;
  
  AppAuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  static bool isAnonymousUser() {
    final user =  FirebaseAuth.instance.currentUser;
    if(user == null || user.phoneNumber == null || user.phoneNumber!.isEmpty){
      return true;
    }
    return false;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
  }
}

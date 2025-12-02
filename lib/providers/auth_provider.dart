import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:startup_20/data/models/user_model.dart';

class AppAuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _firebaseUser;
  AppUser? _appUser;

  User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;

  AppAuthProvider() {
    //  Load the current user immediately
    _firebaseUser = _auth.currentUser;

    // If user already logged in → fetch appUser immediately
    if (_firebaseUser != null) {
      _fetchAppUser(_firebaseUser!.uid);
    }
    _auth.authStateChanges().listen(_authStateChanged);
  }

  /// Handle Firebase auth changes (login / logout)
  Future<void> _authStateChanged(User? user) async {
    _firebaseUser = user;

    // If logged out
    if (user == null) {
      _appUser = null;
      notifyListeners();
      return;
    }

    // Fetch Firestore user ONE TIME
    await _fetchAppUser(user.uid);
  }

  /// Fetch user data only once (no stream)
  Future<void> _fetchAppUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        _appUser = AppUser.fromMap(doc.data()!, doc.id);
      } else {
        _appUser = null;
      }
    } catch (e) {
      debugPrint("⚠️ Error loading user data: $e");
      _appUser = null;
    }

    notifyListeners();
  }

  /// Static check for anonymous user
  static bool isAnonymousUser() {
    final user = FirebaseAuth.instance.currentUser;
    return user == null ||
        user.phoneNumber == null ||
        user.phoneNumber!.isEmpty;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _appUser = null;
    notifyListeners();
  }

  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
  }

  /// Manual reload if needed
  Future<void> reloadUser() async {
    if (_firebaseUser != null) {
      await _fetchAppUser(_firebaseUser!.uid);
    }
  }
}

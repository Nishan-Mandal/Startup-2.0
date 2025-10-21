import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatProvider with ChangeNotifier {
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  ChatProvider() {
    _listenForUnreadMessages();
  }

  void _listenForUnreadMessages() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    FirebaseFirestore.instance
        .collection('conversations')
        .where('participantIds', arrayContains: currentUser.uid)
        .snapshots()
        .listen((snapshot) async {
          int totalUnread = 0;

          for (var doc in snapshot.docs) {
            // Listen for unread messages in each conversation
            FirebaseFirestore.instance
                .collection('conversations')
                .doc(doc.id)
                .collection('messages')
                .where('status', isEqualTo: 'sent')
                .where('senderId', isNotEqualTo: currentUser.uid)
                .snapshots()
                .listen((msgSnapshot) {
                  totalUnread += msgSnapshot.docs.length;
                  _unreadCount = totalUnread;
                  notifyListeners();
                });
          }
        });
  }

  void clearUnread() {
    _unreadCount = 0;
    notifyListeners();
  }
}

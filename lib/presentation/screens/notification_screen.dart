import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  /// Stream user-specific notifications
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getUserNotifications() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      // Anonymous users cannot have notifications
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  /// Marks a user-specific notification as read
  Future<void> _markAsRead(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(doc.id)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Handles navigation when notification is tapped
  void _handleNavigation(BuildContext context, Map<String, dynamic> notif) {
    final data = notif['data'] as Map<String, dynamic>? ?? {};
    final route = data['route'];
    if (route == null) return;

    switch (route) {
      case '/listing':
        final listingId = data['listingId'];
        if (listingId != null) {
          Navigator.pushNamed(
            context,
             '/listing/$listingId',
          );
        }
        break;

      case '/chatRoom':
        final conversationId = data['conversationId'];
        if (conversationId != null) {
          Navigator.pushNamed(
            context,
            route,
            arguments: {'conversationId': conversationId},
          );
        }
        break;

      default:
        Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.GREY_SHADE_100,
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(color: AppColors.WHITE),
        ),
        iconTheme: const IconThemeData(color: AppColors.WHITE),
        centerTitle: true,
        backgroundColor: AppColors.THEME_COLOR,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: AppColors.WHITE),
          ),
        ],
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _getUserNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No notifications yet"));
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final notif = doc.data();
              final title = notif["title"] ?? "";
              final body = notif["body"] ?? "";
              final type = notif["type"] ?? "system";
              final isRead = notif["isRead"] ?? false;
              final createdAt = (notif["createdAt"] as Timestamp?)?.toDate();

              IconData iconData;
              switch (type) {
                case 'offer':
                  iconData = Icons.local_offer;
                  break;
                case 'chat':
                  iconData = Icons.chat_bubble;
                  break;
                case 'reminder':
                  iconData = Icons.alarm;
                  break;
                case 'alert':
                  iconData = Icons.warning;
                  break;
                default:
                  iconData = Icons.notifications;
              }

              return GestureDetector(
                onTap: () async {
                  _handleNavigation(context, notif);
                  await _markAsRead(doc);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isRead ? AppColors.GREY_SHADE_300 : AppColors.WHITE,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (!isRead)
                        BoxShadow(
                          color: AppColors.BLACK_12.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.THEME_COLOR.withOpacity(0.2),
                      child: Icon(iconData, color: AppColors.THEME_COLOR),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(body),
                        const SizedBox(height: 4),
                        Text(
                          CommonMethods.formatMessageTime(createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.BLACK_54,
                          ),
                        ),
                      ],
                    ),
                    trailing: !isRead
                        ? const Icon(
                            Icons.circle,
                            color: AppColors.THEME_COLOR,
                            size: 12,
                          )
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

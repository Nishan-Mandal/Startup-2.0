import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  final List<Map<String, dynamic>> notifications = const [
    {
      "title": "Kudos Earned",
      "message": "You earned 50 Kudos for adding a store.",
      "time": "2m ago",
      "icon": Icons.handshake,
      "color": Colors.amber,
    },
    {
      "title": "Referral Successful",
      "message": "Your friend Soumen joined using your invite. +150 Kudos",
      "time": "1h ago",
      "icon": Icons.group_add,
      "color": Colors.green,
    },
    {
      "title": "New Message",
      "message": "Nishan replied in Haldia group chat.",
      "time": "Yesterday",
      "icon": Icons.chat,
      "color": Colors.blue,
    },
    {
      "title": "System Update",
      "message": "We’ll have scheduled maintenance on 15 Sep, 2 AM.",
      "time": "3d ago",
      "icon": Icons.info,
      "color": Colors.orange,
    },
    {
      "title": "Reward Alert",
      "message": "Special offer: Redeem Kudos for discounts this week!",
      "time": "1w ago",
      "icon": Icons.card_giftcard,
      "color": Colors.red,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Notifications"),
        centerTitle: true,
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: notif["color"].withOpacity(0.2),
                child: Icon(
                  notif["icon"],
                  color: notif["color"],
                ),
              ),
              title: Text(
                notif["title"],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(notif["message"]),
              trailing: Text(
                notif["time"],
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              onTap: () {
                // handle navigation if needed
              },
            ),
          );
        },
      ),
    );
  }
}

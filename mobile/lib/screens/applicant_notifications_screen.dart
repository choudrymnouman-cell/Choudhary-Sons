import 'package:flutter/material.dart';

class ApplicantNotificationsScreen extends StatelessWidget {
  const ApplicantNotificationsScreen({super.key, required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: items.isEmpty
        ? const Center(child: Text('No notifications yet.'))
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final n = items[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(n['notification_type'] == 'interview' ? Icons.video_call_outlined : Icons.notifications_outlined),
                  ),
                  title: Text(n['title']?.toString() ?? 'Notification'),
                  subtitle: Text(n['body']?.toString() ?? ''),
                  trailing: n['is_read'] == true ? null : const Icon(Icons.circle, size: 10),
                ),
              );
            },
          ),
  );
}

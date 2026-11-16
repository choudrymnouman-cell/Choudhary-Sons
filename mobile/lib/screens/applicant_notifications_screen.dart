import 'package:flutter/material.dart';

class ApplicantNotificationsScreen extends StatefulWidget {
  const ApplicantNotificationsScreen({super.key, required this.items, this.onRead});
  final List<Map<String, dynamic>> items;
  final Future<void> Function(int)? onRead;

  @override
  State<ApplicantNotificationsScreen> createState() => _ApplicantNotificationsScreenState();
}

class _ApplicantNotificationsScreenState extends State<ApplicantNotificationsScreen> {
  final read = <int>{};

  Future<void> markRead(int id) async {
    try {
      await widget.onRead?.call(id);
      if (mounted) setState(() => read.add(id));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: widget.items.isEmpty
        ? const Center(child: Text('No notifications yet.'))
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final item = widget.items[index];
              final id = item['id'] as int;
              final isRead = item['is_read'] == true || read.contains(id);
              return Card(child: ListTile(
                leading: CircleAvatar(child: Icon(item['notification_type'] == 'interview'
                  ? Icons.video_call_outlined : Icons.notifications_outlined)),
                title: Text(item['title']?.toString() ?? 'Notification'),
                subtitle: Text(item['body']?.toString() ?? ''),
                trailing: isRead ? null : const Icon(Icons.circle, size: 10),
                onTap: isRead || widget.onRead == null ? null : () => markRead(id),
              ));
            },
          ),
  );
}

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class HrInboxScreen extends StatefulWidget {
  const HrInboxScreen({super.key, required this.userId});

  final String userId;

  @override
  State<HrInboxScreen> createState() => _HrInboxScreenState();
}

class _HrInboxScreenState extends State<HrInboxScreen> {
  final api = RecruitmentHttp();
  final reply = TextEditingController();
  late Future<List<Map<String, dynamic>>> threads = api.rows('conversations');
  Future<List<Map<String, dynamic>>>? messages;
  int? selected;
  bool sending = false;

  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final id = selected;
    final text = reply.text.trim();
    if (id == null || text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await api.post('conversations/$id/messages', {'message': text});
      if (!mounted) return;
      reply.clear();
      setState(() => messages = api.rows('conversations/$id/messages'));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('HR Inbox'),
      actions: [IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: () {
        setState(() {
          threads = api.rows('conversations');
          if (selected != null) messages = api.rows('conversations/$selected/messages');
        });
      })],
    ),
    body: selected == null
      ? _List(future: threads, empty: 'No applicant messages.', tile: (row) => ListTile(
          title: Text('${row['subject']}'),
          subtitle: Text('Applicant ${row['applicant_user_id']}'),
          onTap: () => setState(() {
            selected = row['id'] as int;
            messages = api.rows('conversations/$selected/messages');
          }),
        ))
      : Column(children: [
          Align(alignment: Alignment.centerLeft, child: TextButton(
            onPressed: sending ? null : () => setState(() { selected = null; reply.clear(); }),
            child: const Text('All conversations'),
          )),
          Expanded(child: _List(future: messages!, empty: 'No messages in this conversation.', tile: (row) => ListTile(
            title: Text('${row['message']}'),
            subtitle: Text(row['sender_user_id'].toString() == widget.userId ? 'You' : 'Applicant or HR'),
          ))),
          SafeArea(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: TextField(controller: reply, decoration: const InputDecoration(labelText: 'Reply'),
                onSubmitted: (_) => send())),
              IconButton(onPressed: sending ? null : send, tooltip: 'Send', icon: const Icon(Icons.send)),
            ]),
          )),
        ]),
  );
}

class _List extends StatelessWidget {
  const _List({required this.future, required this.empty, required this.tile});

  final Future<List<Map<String, dynamic>>> future;
  final String empty;
  final Widget Function(Map<String, dynamic>) tile;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snapshot.data!;
      if (rows.isEmpty) return Center(child: Text(empty));
      return ListView(padding: const EdgeInsets.all(12), children: rows.map(tile).toList());
    },
  );
}

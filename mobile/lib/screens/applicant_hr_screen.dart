import 'package:flutter/material.dart';

import '../services/applicant_portal_service.dart';

class ApplicantHrScreen extends StatefulWidget {
  const ApplicantHrScreen({
    super.key,
    required this.service,
    this.applicationId,
    this.applicationTitle,
  });

  final ApplicantPortalService service;
  final int? applicationId;
  final String? applicationTitle;

  @override
  State<ApplicantHrScreen> createState() => _ApplicantHrScreenState();
}

class _ApplicantHrScreenState extends State<ApplicantHrScreen> {
  final message = TextEditingController();
  bool loading = true;
  bool sending = false;
  String? error;
  Map<String, dynamic>? conversation;
  List<dynamic> messages = [];
  List<dynamic> interviews = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final conv = await widget.service.openConversation(
        applicationId: widget.applicationId,
        subject: widget.applicationTitle == null ? 'General HR Support' : 'Application: ${widget.applicationTitle}',
      );
      final result = await Future.wait([
        widget.service.messages(conv['id'] as int),
        widget.service.myInterviews(),
      ]);
      if (!mounted) return;
      setState(() {
        conversation = conv;
        messages = result[0] as List<dynamic>;
        interviews = result[1] as List<dynamic>;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    final conv = conversation;
    final text = message.text.trim();
    if (conv == null || text.isEmpty) return;
    setState(() => sending = true);
    try {
      await widget.service.sendMessage(conv['id'] as int, text);
      message.clear();
      final latest = await widget.service.messages(conv['id'] as int);
      if (mounted) setState(() => messages = latest);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.applicationTitle == null ? 'HR & Interviews' : 'HR • ${widget.applicationTitle}'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline, size: 42),
                      const SizedBox(height: 10),
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      FilledButton(onPressed: load, child: const Text('Retry')),
                    ]),
                  ),
                )
              : LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 850;
                  final chat = _chatPanel();
                  final interview = _interviewPanel();
                  return wide
                      ? Row(children: [Expanded(flex: 3, child: chat), const VerticalDivider(width: 1), Expanded(flex: 2, child: interview)])
                      : ListView(padding: EdgeInsets.zero, children: [SizedBox(height: 520, child: chat), const Divider(height: 1), interview]);
                }),
    );
  }

  Widget _chatPanel() {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: const Color(0xFFEAF4EF),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Chat with HR', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(conversation?['subject']?.toString() ?? 'HR Conversation'),
        ]),
      ),
      Expanded(
        child: messages.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No messages yet. Send a message to HR about your application or interview.')))
            : ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final m = Map<String, dynamic>.from(messages[index] as Map);
                  final mine = m['sender_user_id']?.toString() == conversation?['applicant_user_id']?.toString();
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 520),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: mine ? const Color(0xFF0B5A3C) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: mine ? null : Border.all(color: const Color(0xFFD9E4DE)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m['message']?.toString() ?? '', style: TextStyle(color: mine ? Colors.white : Colors.black87)),
                        const SizedBox(height: 4),
                        Text(
                          m['created_at']?.toString() ?? '',
                          style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : Colors.black45),
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: message,
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => send(),
                decoration: const InputDecoration(hintText: 'Write a message to HR...'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : send,
              icon: sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _interviewPanel() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Interview Center', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('HR interview schedules, video room details and status appear here.'),
        const SizedBox(height: 16),
        if (interviews.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No interview scheduled yet.'))))
        else
          ...interviews.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [Icon(Icons.video_call_outlined), SizedBox(width: 8), Text('Video Interview', style: TextStyle(fontWeight: FontWeight.w800))]),
                    const SizedBox(height: 10),
                    Text('Scheduled: ${m['scheduled_at'] ?? 'To be confirmed'}'),
                    Text('Status: ${m['status'] ?? 'scheduled'}'),
                    Text('Room: ${m['room_code'] ?? 'Will be assigned by HR'}'),
                    if (m['notes'] != null) ...[const SizedBox(height: 6), Text(m['notes'].toString())],
                  ]),
                ),
              ),
            );
          }),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/applicant_portal_service.dart';

class ApplicantHrScreen extends StatelessWidget {
  const ApplicantHrScreen({super.key, required this.service});
  final ApplicantPortalService service;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('HR & Interviews')),
    body: FutureBuilder<List<dynamic>>(
      future: service.myInterviews(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('Interview Center', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('HR interview schedules and video meeting details will appear here.'),
            const SizedBox(height: 16),
            if (rows.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No interview scheduled yet.')))),
            ...rows.map((e) { final m = Map<String,dynamic>.from(e as Map); return Card(child: ListTile(leading: const Icon(Icons.video_call_outlined), title: Text(m['scheduled_at']?.toString() ?? 'Scheduled interview'), subtitle: Text('Status: ${m['status'] ?? 'scheduled'}\nRoom: ${m['room_code'] ?? 'Will be assigned by HR'}'), isThreeLine: true)); }),
          ],
        );
      },
    ),
  );
}

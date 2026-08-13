import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/applicant_portal_service.dart';
import 'applicant_profile_screen.dart';
import 'applicant_hr_screen.dart';

const portalGreen = Color(0xFF0B5A3C);

class ApplicantDashboard extends StatefulWidget {
  const ApplicantDashboard({super.key, required this.session});
  final AuthSession session;

  @override
  State<ApplicantDashboard> createState() => _ApplicantDashboardState();
}

class _ApplicantDashboardState extends State<ApplicantDashboard> {
  final service = ApplicantPortalService();
  bool loading = true;
  Map<String, dynamic>? profile;
  List<dynamic> jobs = [];
  List<dynamic> applications = [];
  List<dynamic> interviews = [];

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final r = await Future.wait([service.myProfile(), service.openJobs(), service.myApplications(), service.myInterviews()]);
      if (!mounted) return;
      setState(() { profile = r[0] as Map<String, dynamic>?; jobs = r[1] as List<dynamic>; applications = r[2] as List<dynamic>; interviews = r[3] as List<dynamic>; });
    } finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final complete = profile?['is_profile_complete'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Choudhary & Sons Careers'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh)), IconButton(onPressed: () async { await ApiService().signOut(); if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst); }, icon: const Icon(Icons.logout))]),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF073D2A), portalGreen]), borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome, ${profile?['full_name'] ?? widget.session.fullName}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(complete ? 'Your profile is ready for applications.' : 'Complete your profile and ID documents before applying.', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: portalGreen), onPressed: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApplicantProfileScreen(service: service, initial: profile))); load(); }, icon: const Icon(Icons.person_outline), label: Text(complete ? 'View Profile' : 'Complete Profile')),
            ]),
          ),
          const SizedBox(height: 16),
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5, children: [
            _Stat(icon: Icons.work_outline, value: '${jobs.length}', label: 'Open Jobs'),
            _Stat(icon: Icons.assignment_outlined, value: '${applications.length}', label: 'Applications'),
            _Stat(icon: Icons.video_call_outlined, value: '${interviews.length}', label: 'Interviews'),
            _Stat(icon: complete ? Icons.verified : Icons.warning_amber, value: complete ? 'Ready' : 'Pending', label: 'Profile'),
          ]),
          const SizedBox(height: 18),
          Row(children: [const Expanded(child: Text('Jobs announced by HR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApplicantHrScreen(service: service))), icon: const Icon(Icons.chat_bubble_outline), label: const Text('HR Chat'))]),
          const SizedBox(height: 8),
          if (jobs.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No open jobs right now.')))) else ...jobs.map((e) {
            final job = Map<String, dynamic>.from(e as Map);
            final applied = applications.any((a) => (a as Map)['vacancy_id'] == job['id']);
            return Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(job['title']?.toString() ?? 'Job', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${job['department'] ?? 'General'} • ${job['location'] ?? 'Pakistan'}'),
              const SizedBox(height: 8),
              Text(job['description']?.toString() ?? ''),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: applied ? null : () async { try { await service.applyForJob(vacancyId: job['id'] as int); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted.'))); await load(); } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', '')))); } }, icon: Icon(applied ? Icons.check : Icons.send_outlined), label: Text(applied ? 'Applied' : 'Apply Now'))),
            ]))));
          }),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon; final String value; final String label;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: portalGreen), const Spacer(), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 12))])));
}

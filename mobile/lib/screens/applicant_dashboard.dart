import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/applicant_portal_service.dart';
import '../services/applicant_saved_jobs_service.dart';
import '../services/applicant_career_features_service.dart';
import 'applicant_profile_screen.dart';
import 'applicant_hr_screen.dart';
import 'applicant_notifications_screen.dart';

const portalGreen = Color(0xFF0B5A3C);
const portalDark = Color(0xFF073D2A);
const portalSoft = Color(0xFFEAF4EF);

class ApplicantDashboard extends StatefulWidget {
  const ApplicantDashboard({super.key, required this.session});
  final AuthSession session;

  @override
  State<ApplicantDashboard> createState() => _ApplicantDashboardState();
}

class _ApplicantDashboardState extends State<ApplicantDashboard> {
  final service = ApplicantPortalService();
  final savedService = ApplicantSavedJobsService();
  final careerService = ApplicantCareerFeaturesService();
  final search = TextEditingController();

  bool loading = true;
  String? error;
  String query = '';
  Map<String, dynamic>? profile;
  List<dynamic> jobs = [];
  List<dynamic> applications = [];
  List<dynamic> interviews = [];
  List<Map<String, dynamic>> notifications = [];
  Set<int> savedJobIds = {};

  @override
  void initState() { super.initState(); load(); }

  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      await service.ensureApplicantRole();
      final r = await Future.wait([
        service.myProfile(), service.openJobs(), service.myApplications(), service.myInterviews(), savedService.savedJobs(), careerService.notifications(),
      ]);
      if (!mounted) return;
      final saved = r[4] as List<dynamic>;
      setState(() {
        profile = r[0] as Map<String, dynamic>?;
        jobs = r[1] as List<dynamic>;
        applications = r[2] as List<dynamic>;
        interviews = r[3] as List<dynamic>;
        savedJobIds = saved.map((e) => (e as Map)['vacancy_id'] as int).toSet();
        notifications = (r[5] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => loading = false); }
  }

  int get profileProgress {
    final p = profile ?? const <String, dynamic>{};
    const keys = ['full_name','father_name','cnic','cnic_name','whatsapp_number','education','experience_details','skills','address','city','profile_photo_path','cnic_front_path','cnic_back_path'];
    final done = keys.where((k) => p[k] != null && p[k].toString().trim().isNotEmpty).length;
    return ((done / keys.length) * 100).round();
  }

  int get unreadNotifications => notifications.where((n) => n['is_read'] != true).length;

  Future<void> _openProfile() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApplicantProfileScreen(service: service, initial: profile)));
    await load();
  }

  Future<void> _apply(Map<String, dynamic> job) async {
    final cover = TextEditingController();
    final salary = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('Apply for ${job['title'] ?? 'Job'}'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: cover, maxLines: 4, decoration: const InputDecoration(labelText: 'Cover letter / message to HR')),
        const SizedBox(height: 12),
        TextField(controller: salary, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Expected salary (optional)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit Application'))],
    ));
    if (ok != true) return;
    try {
      await service.applyForJob(vacancyId: job['id'] as int, coverLetter: cover.text, expectedSalary: double.tryParse(salary.text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted successfully.')));
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { cover.dispose(); salary.dispose(); }
  }

  Future<void> _toggleSave(int jobId) async {
    try {
      final saved = savedJobIds.contains(jobId);
      if (saved) { await savedService.unsaveJob(jobId); } else { await savedService.saveJob(jobId); }
      if (!mounted) return;
      setState(() => saved ? savedJobIds.remove(jobId) : savedJobIds.add(jobId));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApplicantNotificationsScreen(items: notifications)));
    for (final n in notifications.where((n) => n['is_read'] != true)) {
      final id = n['id'];
      if (id is int) await careerService.markNotificationRead(id);
    }
    await load();
  }

  Future<void> _openPreferences() async {
    final current = await careerService.preferences();
    if (!mounted) return;
    final dept = TextEditingController(text: current?['preferred_department']?.toString() ?? '');
    final location = TextEditingController(text: current?['preferred_location']?.toString() ?? '');
    final type = TextEditingController(text: current?['preferred_employment_type']?.toString() ?? '');
    final salary = TextEditingController(text: current?['min_expected_salary']?.toString() ?? '');
    bool alerts = current?['receive_job_alerts'] != false;
    final saved = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Career Preferences'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: dept, decoration: const InputDecoration(labelText: 'Preferred department')),
        const SizedBox(height: 10),
        TextField(controller: location, decoration: const InputDecoration(labelText: 'Preferred location')),
        const SizedBox(height: 10),
        TextField(controller: type, decoration: const InputDecoration(labelText: 'Employment type')),
        const SizedBox(height: 10),
        TextField(controller: salary, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum expected salary')),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: alerts, onChanged: (v) => setLocal(() => alerts = v), title: const Text('Receive job alerts')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
    )));
    if (saved == true) {
      await careerService.savePreferences(department: dept.text, location: location.text, employmentType: type.text, minSalary: double.tryParse(salary.text), receiveJobAlerts: alerts);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Career preferences saved.')));
    }
    dept.dispose(); location.dispose(); type.dispose(); salary.dispose();
  }

  Future<void> _signOut() async {
    await ApiService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const _ApplicantSignedOutPlaceholder()), (_) => false);
  }

  List<Map<String, dynamic>> get filteredJobs {
    final q = query.trim().toLowerCase();
    return jobs.map((e) => Map<String, dynamic>.from(e as Map)).where((job) {
      if (q.isEmpty) return true;
      final haystack = '${job['title']} ${job['department']} ${job['location']} ${job['employment_type']} ${job['description']}'.toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final complete = profile?['is_profile_complete'] == true;
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Choudhary & Sons Careers', style: TextStyle(fontWeight: FontWeight.w800)), Text('Applicant Portal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal))]),
        actions: [
          Badge(label: Text('$unreadNotifications'), isLabelVisible: unreadNotifications > 0, child: IconButton(tooltip: 'Notifications', onPressed: _openNotifications, icon: const Icon(Icons.notifications_outlined))),
          IconButton(tooltip: 'Career preferences', onPressed: _openPreferences, icon: const Icon(Icons.tune)),
          IconButton(tooltip: 'Refresh', onPressed: load, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Sign out', onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(onRefresh: load, child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1180), child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 32), children: [
        if (error != null) ...[_ErrorBanner(message: error!, onRetry: load), const SizedBox(height: 14)],
        _HeroCard(name: (profile?['full_name'] ?? widget.session.fullName).toString(), email: widget.session.email, progress: profileProgress, complete: complete, onProfile: _openProfile),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (_, c) { final cols = c.maxWidth >= 850 ? 4 : 2; return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: c.maxWidth >= 850 ? 2.05 : 1.45, children: [
          _Stat(icon: Icons.work_outline, value: '${jobs.length}', label: 'Open Jobs'), _Stat(icon: Icons.bookmark_outline, value: '${savedJobIds.length}', label: 'Saved Jobs'), _Stat(icon: Icons.assignment_turned_in_outlined, value: '${applications.length}', label: 'Applications'), _Stat(icon: Icons.video_call_outlined, value: '${interviews.length}', label: 'Interviews'),
        ]); }),
        const SizedBox(height: 18),
        _QuickActions(onProfile: _openProfile, onChat: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApplicantHrScreen(service: service))), hasInterview: interviews.isNotEmpty),
        const SizedBox(height: 18),
        TextField(controller: search, onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search jobs', hintText: 'Title, location, department...')),
        const SizedBox(height: 14),
        Text('Jobs announced by HR (${filteredJobs.length})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (filteredJobs.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No matching open jobs right now.')))) else ...filteredJobs.map((job) {
          final applied = applications.any((a) => (a as Map)['vacancy_id'] == job['id']);
          final saved = savedJobIds.contains(job['id']);
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(job['title']?.toString() ?? 'Job', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), IconButton(onPressed: () => _toggleSave(job['id'] as int), icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: portalGreen))]),
            Wrap(spacing: 8, runSpacing: 8, children: [Chip(label: Text(job['department']?.toString() ?? 'General')), Chip(label: Text(job['location']?.toString() ?? 'Pakistan')), if (job['employment_type'] != null) Chip(label: Text(job['employment_type'].toString())), if (job['salary_max'] != null || job['salary_min'] != null) Chip(label: Text('PKR ${job['salary_min'] ?? ''}${job['salary_max'] != null ? ' - ${job['salary_max']}' : ''}'))]),
            const SizedBox(height: 10), Text(job['description']?.toString() ?? ''), const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: applied ? null : () => _apply(job), icon: Icon(applied ? Icons.check : Icons.send_outlined), label: Text(applied ? 'Application Submitted' : complete ? 'Apply Now' : 'Complete Profile to Apply'))),
          ]))));
        }),
        if (applications.isNotEmpty) ...[
          const SizedBox(height: 16), const Text('My Applications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
          ...applications.map((e) { final a = Map<String, dynamic>.from(e as Map); final job = a['job_vacancies'] is Map ? Map<String, dynamic>.from(a['job_vacancies'] as Map) : <String, dynamic>{}; return Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(leading: const Icon(Icons.assignment_turned_in_outlined, color: portalGreen), title: Text(job['title']?.toString() ?? 'Job Application'), subtitle: Text('${job['department'] ?? ''} • Status: ${a['status'] ?? 'applied'}'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApplicantHrScreen(service: service, applicationId: a['id'] as int?, applicationTitle: job['title']?.toString())))))); }),
        ],
        if (interviews.isNotEmpty) ...[
          const SizedBox(height: 16), const Text('Upcoming Interviews', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
          ...interviews.take(3).map((e) { final m = Map<String, dynamic>.from(e as Map); return Card(child: ListTile(leading: const Icon(Icons.video_call_outlined, color: portalGreen), title: Text(m['scheduled_at']?.toString() ?? 'Interview'), subtitle: Text('Status: ${m['status'] ?? 'scheduled'} • Room: ${m['room_code'] ?? 'TBA'}'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApplicantHrScreen(service: service)))); }),
        ],
      ])))),
    );
  }
}

class _ErrorBanner extends StatelessWidget { const _ErrorBanner({required this.message, required this.onRetry}); final String message; final VoidCallback onRetry; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error), const SizedBox(width: 10), Expanded(child: Text(message)), TextButton(onPressed: onRetry, child: const Text('Retry'))])); }
class _HeroCard extends StatelessWidget { const _HeroCard({required this.name, required this.email, required this.progress, required this.complete, required this.onProfile}); final String name; final String email; final int progress; final bool complete; final VoidCallback onProfile; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [portalDark, portalGreen]), borderRadius: BorderRadius.circular(22)), child: LayoutBuilder(builder: (_, c) { final wide = c.maxWidth > 650; final details = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Welcome, $name', style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(email, style: const TextStyle(color: Colors.white70)), const SizedBox(height: 14), Text(complete ? 'Your profile is ready for job applications.' : 'Build a strong profile to improve your chances.', style: const TextStyle(color: Colors.white70)), const SizedBox(height: 12), FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: portalGreen), onPressed: onProfile, icon: const Icon(Icons.person_outline), label: Text(complete ? 'View / Edit Profile' : 'Complete Profile'))]); final progressBox = SizedBox(width: 170, child: Column(mainAxisSize: MainAxisSize.min, children: [Text('$progress%', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)), const Text('Profile strength', style: TextStyle(color: Colors.white70)), const SizedBox(height: 8), LinearProgressIndicator(value: progress / 100, minHeight: 8, backgroundColor: Colors.white24)])); return wide ? Row(children: [Expanded(child: details), const SizedBox(width: 24), progressBox]) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [details, const SizedBox(height: 18), progressBox]); })); }
class _QuickActions extends StatelessWidget { const _QuickActions({required this.onProfile, required this.onChat, required this.hasInterview}); final VoidCallback onProfile; final VoidCallback onChat; final bool hasInterview; @override Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [OutlinedButton.icon(onPressed: onProfile, icon: const Icon(Icons.badge_outlined), label: const Text('My Profile & Documents')), OutlinedButton.icon(onPressed: onChat, icon: const Icon(Icons.chat_bubble_outline), label: const Text('HR Chat')), if (hasInterview) OutlinedButton.icon(onPressed: onChat, icon: const Icon(Icons.video_call_outlined), label: const Text('Interview Center'))]); }
class _Stat extends StatelessWidget { const _Stat({required this.icon, required this.value, required this.label}); final IconData icon; final String value; final String label; @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: portalGreen), const Spacer(), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 12))]))); }
class _ApplicantSignedOutPlaceholder extends StatelessWidget { const _ApplicantSignedOutPlaceholder(); @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('You have been signed out. Refresh the page to sign in again.'))); }

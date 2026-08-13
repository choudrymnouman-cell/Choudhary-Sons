import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/applicant_portal_service.dart';
import '../services/applicant_saved_jobs_service.dart';
import 'applicant_profile_screen.dart';
import 'applicant_hr_screen.dart';

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
  final search = TextEditingController();

  bool loading = true;
  String? error;
  String query = '';
  Map<String, dynamic>? profile;
  List<dynamic> jobs = [];
  List<dynamic> applications = [];
  List<dynamic> interviews = [];
  Set<int> savedJobIds = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      await service.ensureApplicantRole();
      final r = await Future.wait([
        service.myProfile(),
        service.openJobs(),
        service.myApplications(),
        service.myInterviews(),
        savedService.savedJobs(),
      ]);
      if (!mounted) return;
      final saved = r[4] as List<dynamic>;
      setState(() {
        profile = r[0] as Map<String, dynamic>?;
        jobs = r[1] as List<dynamic>;
        applications = r[2] as List<dynamic>;
        interviews = r[3] as List<dynamic>;
        savedJobIds = saved.map((e) => (e as Map)['vacancy_id'] as int).toSet();
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  int get profileProgress {
    final p = profile ?? const <String, dynamic>{};
    const keys = [
      'full_name','father_name','cnic','cnic_name','whatsapp_number','education',
      'experience_details','skills','address','city','profile_photo_path','cnic_front_path','cnic_back_path'
    ];
    final done = keys.where((k) => p[k] != null && p[k].toString().trim().isNotEmpty).length;
    return ((done / keys.length) * 100).round();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ApplicantProfileScreen(service: service, initial: profile)),
    );
    await load();
  }

  Future<void> _apply(Map<String, dynamic> job) async {
    try {
      await service.applyForJob(vacancyId: job['id'] as int);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted successfully.')));
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _toggleSave(int jobId) async {
    try {
      final saved = savedJobIds.contains(jobId);
      if (saved) {
        await savedService.unsaveJob(jobId);
      } else {
        await savedService.saveJob(jobId);
      }
      if (!mounted) return;
      setState(() => saved ? savedJobIds.remove(jobId) : savedJobIds.add(jobId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _signOut() async {
    await ApiService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const _ApplicantSignedOutPlaceholder()),
      (_) => false,
    );
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
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Choudhary & Sons Careers', style: TextStyle(fontWeight: FontWeight.w800)),
          Text('Applicant Portal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
        ]),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: load, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Sign out', onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                if (error != null) ...[
                  _ErrorBanner(message: error!, onRetry: load),
                  const SizedBox(height: 14),
                ],
                _HeroCard(
                  name: (profile?['full_name'] ?? widget.session.fullName).toString(),
                  email: widget.session.email,
                  progress: profileProgress,
                  complete: complete,
                  onProfile: _openProfile,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (_, c) {
                  final cols = c.maxWidth >= 850 ? 4 : 2;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: c.maxWidth >= 850 ? 2.05 : 1.45,
                    children: [
                      _Stat(icon: Icons.work_outline, value: '${jobs.length}', label: 'Open Jobs'),
                      _Stat(icon: Icons.bookmark_outline, value: '${savedJobIds.length}', label: 'Saved Jobs'),
                      _Stat(icon: Icons.assignment_turned_in_outlined, value: '${applications.length}', label: 'Applications'),
                      _Stat(icon: Icons.video_call_outlined, value: '${interviews.length}', label: 'Interviews'),
                    ],
                  );
                }),
                const SizedBox(height: 18),
                _QuickActions(
                  onProfile: _openProfile,
                  onChat: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApplicantHrScreen(service: service))),
                  hasInterview: interviews.isNotEmpty,
                ),
                const SizedBox(height: 22),
                Row(children: [
                  const Expanded(child: Text('Find your next opportunity', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                  if (savedJobIds.isNotEmpty) Chip(avatar: const Icon(Icons.bookmark, size: 16), label: Text('${savedJobIds.length} saved')),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: search,
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    hintText: 'Search by job title, department or location',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty ? null : IconButton(onPressed: () { search.clear(); setState(() => query = ''); }, icon: const Icon(Icons.close)),
                  ),
                ),
                const SizedBox(height: 12),
                if (filteredJobs.isEmpty)
                  const _EmptyState(icon: Icons.work_off_outlined, title: 'No matching jobs', subtitle: 'New HR vacancies will appear here when announced.')
                else
                  ...filteredJobs.map((job) {
                    final applied = applications.any((a) => (a as Map)['vacancy_id'] == job['id']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _JobCard(
                        job: job,
                        applied: applied,
                        complete: complete,
                        saved: savedJobIds.contains(job['id']),
                        onSave: () => _toggleSave(job['id'] as int),
                        onApply: () => _apply(job),
                      ),
                    );
                  }),
                if (applications.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Application Progress', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  ...applications.map((e) {
                    final a = Map<String, dynamic>.from(e as Map);
                    final j = a['job_vacancies'] is Map ? Map<String, dynamic>.from(a['job_vacancies'] as Map) : <String, dynamic>{};
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ApplicationCard(
                        title: j['title']?.toString() ?? 'Job Application',
                        department: j['department']?.toString() ?? '',
                        status: a['status']?.toString() ?? 'applied',
                        onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ApplicantHrScreen(service: service, applicationId: a['id'] as int?, applicationTitle: j['title']?.toString()),
                        )),
                      ),
                    );
                  }),
                ],
                if (interviews.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Upcoming Interviews', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  ...interviews.take(3).map((e) {
                    final i = Map<String, dynamic>.from(e as Map);
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: portalSoft, child: Icon(Icons.video_call, color: portalGreen)),
                        title: Text(i['scheduled_at']?.toString() ?? 'Interview scheduled'),
                        subtitle: Text('Status: ${i['status'] ?? 'scheduled'} • Room: ${i['room_code'] ?? 'TBA'}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApplicantHrScreen(service: service))),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.name, required this.email, required this.progress, required this.complete, required this.onProfile});
  final String name;
  final String email;
  final int progress;
  final bool complete;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [portalDark, portalGreen], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: portalGreen.withValues(alpha: .18), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: LayoutBuilder(builder: (_, c) {
          final compact = c.maxWidth < 620;
          final identity = Row(children: [
            CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Text(name.isEmpty ? 'A' : name[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: portalGreen))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome, $name', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(email, style: const TextStyle(color: Colors.white70)),
            ])),
          ]);
          final progressBox = SizedBox(
            width: compact ? double.infinity : 270,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(complete ? 'Profile verified for applications' : 'Profile completion', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))), Text('$progress%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))]),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress / 100, minHeight: 8, borderRadius: BorderRadius.circular(20), backgroundColor: Colors.white24, color: Colors.white),
              const SizedBox(height: 12),
              FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: portalGreen), onPressed: onProfile, icon: Icon(complete ? Icons.edit_outlined : Icons.person_add_alt), label: Text(complete ? 'Edit Profile' : 'Complete Profile')),
            ]),
          );
          if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [identity, const SizedBox(height: 18), progressBox]);
          return Row(children: [Expanded(child: identity), const SizedBox(width: 24), progressBox]);
        }),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onProfile, required this.onChat, required this.hasInterview});
  final VoidCallback onProfile;
  final VoidCallback onChat;
  final bool hasInterview;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            _Action(icon: Icons.person_outline, label: 'My Profile', onTap: onProfile),
            _Action(icon: Icons.chat_bubble_outline, label: 'HR Chat', onTap: onChat),
            _Action(icon: Icons.video_call_outlined, label: hasInterview ? 'Interview Center' : 'Interview Status', onTap: onChat),
            _Action(icon: Icons.folder_copy_outlined, label: 'My Documents', onTap: onProfile),
          ]),
        ),
      );
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(width: 155, child: OutlinedButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label)));
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.applied, required this.complete, required this.saved, required this.onSave, required this.onApply});
  final Map<String, dynamic> job;
  final bool applied;
  final bool complete;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: portalSoft, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.engineering_outlined, color: portalGreen)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(job['title']?.toString() ?? 'Job', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('${job['department'] ?? 'General'} • ${job['location'] ?? 'Pakistan'}', style: TextStyle(color: Colors.grey.shade700)),
              ])),
              IconButton(tooltip: saved ? 'Remove saved job' : 'Save job', onPressed: onSave, icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: portalGreen)),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (job['employment_type'] != null) Chip(label: Text(job['employment_type'].toString().replaceAll('_', ' '))),
              if (job['salary_min'] != null || job['salary_max'] != null) Chip(label: Text('PKR ${job['salary_min'] ?? '-'} - ${job['salary_max'] ?? '-'}')),
              if (applied) const Chip(avatar: Icon(Icons.check_circle, size: 16), label: Text('Applied')),
            ]),
            const SizedBox(height: 10),
            Text(job['description']?.toString() ?? '', maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: applied ? null : onApply,
              icon: Icon(applied ? Icons.check : complete ? Icons.send_outlined : Icons.person_outline),
              label: Text(applied ? 'Application Submitted' : complete ? 'Apply Now' : 'Complete Profile to Apply'),
            )),
          ]),
        ),
      );
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.title, required this.department, required this.status, required this.onOpen});
  final String title;
  final String department;
  final String status;
  final VoidCallback onOpen;

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'hired': return Colors.green;
      case 'rejected': return Colors.red;
      case 'interview': return Colors.deepPurple;
      case 'shortlisted': return Colors.blue;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(backgroundColor: statusColor.withValues(alpha: .12), child: Icon(Icons.assignment_turned_in_outlined, color: statusColor)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (department.isNotEmpty) Text(department, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)), const SizedBox(width: 6), Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 12))]),
            ])),
            IconButton(onPressed: onOpen, icon: const Icon(Icons.chat_bubble_outline), tooltip: 'Open HR conversation'),
          ]),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 38, height: 38, decoration: BoxDecoration(color: portalSoft, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: portalGreen, size: 21)),
    const Spacer(),
    Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
    Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
  ])));
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(14)),
    child: Row(children: [Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error), const SizedBox(width: 10), Expanded(child: Text(message)), TextButton(onPressed: onRetry, child: const Text('Retry'))]),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(28), child: Center(child: Column(children: [Icon(icon, size: 42, color: portalGreen), const SizedBox(height: 10), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, textAlign: TextAlign.center)]))));
}

class _ApplicantSignedOutPlaceholder extends StatelessWidget {
  const _ApplicantSignedOutPlaceholder();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Signed out. Refresh the page to sign in again.')));
}

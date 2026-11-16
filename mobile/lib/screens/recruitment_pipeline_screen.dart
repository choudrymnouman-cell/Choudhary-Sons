import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/api_service.dart';
import '../services/recruitment_pipeline_service.dart';
import 'admin_create_forms.dart';
import 'hr_inbox_screen.dart';

const _green = Color(0xFF0B5A3C);

class RecruitmentPipelineScreen extends StatefulWidget {
  const RecruitmentPipelineScreen({super.key, required this.session});
  final AuthSession session;

  @override
  State<RecruitmentPipelineScreen> createState() => _RecruitmentPipelineScreenState();
}

class _RecruitmentPipelineScreenState extends State<RecruitmentPipelineScreen> {
  final service = RecruitmentPipelineService();
  String filter = 'all';
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { rows = await service.applications(); }
    catch (e) { error = e.toString().replaceFirst('Exception: ', ''); }
    finally { if (mounted) setState(() => loading = false); }
  }

  List<Map<String, dynamic>> get visible => filter == 'all' ? rows : rows.where((e) => e['status']?.toString() == filter).toList();

  Future<void> _open(Map<String, dynamic> app) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ApplicantReviewScreen(application: app, service: service)));
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recruitment Pipeline'), actions: [
      if (selfHostedWeb)
        IconButton(tooltip: 'HR inbox', icon: const Icon(Icons.inbox_outlined), onPressed: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => HrInboxScreen(userId: widget.session.userId)))),
      if (selfHostedWeb)
        IconButton(tooltip: 'Vacancies', icon: const Icon(Icons.work_outline), onPressed: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => VacancyListScreen(session: widget.session)))),
      IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
    ]),
    body: loading ? const Center(child: CircularProgressIndicator()) : error != null ? Center(child: Text(error!)) : Column(children: [
      SizedBox(height: 64, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(10), children: ['all','applied','shortlisted','interview','hired','rejected'].map((s) => Padding(
        padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(s == 'all' ? 'All' : s[0].toUpperCase()+s.substring(1)), selected: filter == s, onSelected: (_) => setState(() => filter = s)),
      )).toList())),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
        _Metric(label: 'Total', value: rows.length), const SizedBox(width: 8),
        _Metric(label: 'Shortlisted', value: rows.where((e) => e['status'] == 'shortlisted').length), const SizedBox(width: 8),
        _Metric(label: 'Interviews', value: rows.where((e) => e['status'] == 'interview').length), const SizedBox(width: 8),
        _Metric(label: 'Hired', value: rows.where((e) => e['status'] == 'hired').length),
      ])),
      const SizedBox(height: 12),
      Expanded(child: visible.isEmpty ? const Center(child: Text('No applications in this stage.')) : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), itemCount: visible.length, itemBuilder: (_, i) {
          final a = visible[i];
          final job = a['job_vacancies'] is Map ? Map<String,dynamic>.from(a['job_vacancies'] as Map) : <String,dynamic>{};
          return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
            leading: CircleAvatar(backgroundColor: const Color(0xFFEAF4EF), child: Text((a['applicant_name'] ?? 'A').toString()[0].toUpperCase(), style: const TextStyle(color: _green, fontWeight: FontWeight.bold))),
            title: Text(a['applicant_name']?.toString() ?? 'Applicant', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${job['title'] ?? 'Job'} • ${a['email'] ?? ''}\nExperience: ${a['experience_years'] ?? 0} yrs • Expected: ${a['expected_salary'] ?? '-'}'),
            isThreeLine: true,
            trailing: Chip(label: Text((a['status'] ?? 'applied').toString())),
            onTap: () => _open(a),
          ));
        },
      )),
    ]),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label; final int value;
  @override Widget build(BuildContext context) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _green)), Text(label, style: const TextStyle(fontSize: 11))]))));
}

class ApplicantReviewScreen extends StatefulWidget {
  const ApplicantReviewScreen({super.key, required this.application, required this.service});
  final Map<String,dynamic> application;
  final RecruitmentPipelineService service;
  @override State<ApplicantReviewScreen> createState() => _ApplicantReviewScreenState();
}

class _ApplicantReviewScreenState extends State<ApplicantReviewScreen> {
  Map<String,dynamic>? profile;
  List<Map<String,dynamic>> notes = [];
  bool loading = true;

  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    final uid = widget.application['applicant_user_id']?.toString();
    final r = await Future.wait([if (uid != null) widget.service.applicantProfile(uid), widget.service.notes(widget.application['id'] as int)]);
    if (!mounted) return;
    setState(() { if (uid != null) profile = r[0] as Map<String,dynamic>?; notes = r.last as List<Map<String,dynamic>>; loading = false; });
  }

  Future<void> _submit(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> status(String value) => _submit(() async {
    await widget.service.setStatus(widget.application['id'] as int, value);
    if (mounted) Navigator.pop(context, true);
  });

  Future<void> _download(String fileId) => _submit(() async {
    final file = await RecruitmentHttp().download(fileId);
    await FilePicker.platform.saveFile(fileName: file.name, bytes: file.bytes);
  });

  Future<void> addNote() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Add HR Note'), content: TextField(controller: c, maxLines: 4, decoration: const InputDecoration(hintText: 'Private note about applicant')), actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancel')), FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Save'))]));
    if (ok == true) await _submit(() async { await widget.service.addNote(widget.application['id'] as int, c.text); await load(); });
    c.dispose();
  }

  Future<void> interview() async {
    final date = TextEditingController(text: DateTime.now().add(const Duration(days:1)).toIso8601String().substring(0,16));
    final url = TextEditingController(); final room = TextEditingController(); final note = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Schedule Interview'), content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: date, decoration: const InputDecoration(labelText: 'Date/time (YYYY-MM-DDTHH:MM)')), const SizedBox(height:8), TextField(controller: url, decoration: const InputDecoration(labelText: 'Video meeting URL')), const SizedBox(height:8), TextField(controller: room, decoration: const InputDecoration(labelText: 'Room code')), const SizedBox(height:8), TextField(controller: note, decoration: const InputDecoration(labelText: 'Interview notes'))])), actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancel')), FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Schedule'))]));
    if (ok == true) {
      await _submit(() async {
      await widget.service.scheduleInterview(applicationId: widget.application['id'] as int, applicantUserId: widget.application['applicant_user_id'].toString(), scheduledAt: DateTime.parse(date.text), meetingUrl: url.text, roomCode: room.text, notes: note.text);
      if (mounted) Navigator.pop(context, true);
      });
    }
    date.dispose(); url.dispose(); room.dispose(); note.dispose();
  }

  Future<void> hire() async {
    final code = TextEditingController(); final designation = TextEditingController(); final dept = TextEditingController(); final salary = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Hire Applicant'), content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: code, decoration: const InputDecoration(labelText: 'Employee code')), const SizedBox(height:8), TextField(controller: designation, decoration: const InputDecoration(labelText: 'Designation')), const SizedBox(height:8), TextField(controller: dept, decoration: const InputDecoration(labelText: 'Department')), const SizedBox(height:8), TextField(controller: salary, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Basic salary'))])), actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancel')), FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Create Employee'))]));
    if (ok == true) {
      await _submit(() async {
      await widget.service.hire(applicationId: widget.application['id'] as int, employeeCode: code.text, designation: designation.text, department: dept.text, basicSalary: double.tryParse(salary.text) ?? 0);
      if (mounted) Navigator.pop(context, true);
      });
    }
    code.dispose(); designation.dispose(); dept.dispose(); salary.dispose();
  }

  @override Widget build(BuildContext context) {
    final a = widget.application;
    final job = a['job_vacancies'] is Map ? Map<String,dynamic>.from(a['job_vacancies'] as Map) : <String,dynamic>{};
    return Scaffold(appBar: AppBar(title: Text(a['applicant_name']?.toString() ?? 'Applicant Review')), body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(job['title']?.toString() ?? 'Application', style: const TextStyle(fontSize:20,fontWeight:FontWeight.w900)), const SizedBox(height:8), Text('${a['email'] ?? ''} • ${a['phone'] ?? ''}'), Text('CNIC: ${a['cnic'] ?? '-'}'), Text('Experience: ${a['experience_years'] ?? 0} years'), if (a['cover_letter'] != null) ...[const SizedBox(height:10), Text('Cover letter: ${a['cover_letter']}')]]))),
      const SizedBox(height:12),
      if (profile != null) Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Full Applicant Profile', style: TextStyle(fontSize:18,fontWeight:FontWeight.w800)), const SizedBox(height:8), Text('Father: ${profile!['father_name'] ?? '-'}'), Text('Education: ${profile!['education'] ?? '-'}'), Text('Skills: ${profile!['skills'] ?? '-'}'), Text('City: ${profile!['city'] ?? '-'}'), Text('Bank: ${profile!['bank_name'] ?? '-'} • ${profile!['bank_account_number'] ?? '-'}'), Text('Experience details: ${profile!['experience_details'] ?? '-'}')]))),
      if (selfHostedWeb && profile != null)
        Wrap(spacing: 8, children: [
          for (final entry in const {
            'profile_photo_path': 'Profile photo',
            'cnic_front_path': 'CNIC front',
            'cnic_back_path': 'CNIC back',
            'experience_document_path': 'Experience document',
          }.entries)
            if (profile![entry.key] is String)
              OutlinedButton.icon(onPressed: () => _download(profile![entry.key] as String),
                icon: const Icon(Icons.download), label: Text(entry.value)),
        ]),
      const SizedBox(height:12),
      Wrap(spacing:8, runSpacing:8, children:[OutlinedButton.icon(onPressed: ()=>status('rejected'), icon: const Icon(Icons.close), label: const Text('Reject')), OutlinedButton.icon(onPressed: ()=>status('shortlisted'), icon: const Icon(Icons.star_outline), label: const Text('Shortlist')), FilledButton.icon(onPressed: interview, icon: const Icon(Icons.video_call_outlined), label: const Text('Schedule Interview')), FilledButton.icon(onPressed: hire, icon: const Icon(Icons.badge_outlined), label: const Text('Hire & Create Employee'))]),
      const SizedBox(height:18),
      Row(children:[const Expanded(child: Text('Private HR Notes', style: TextStyle(fontSize:18,fontWeight:FontWeight.w800))), IconButton(onPressed:addNote, icon: const Icon(Icons.add_comment_outlined))]),
      if (notes.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No HR notes yet.'))) else ...notes.map((n)=>Card(child: ListTile(leading: const Icon(Icons.note_alt_outlined), title: Text(n['note']?.toString() ?? ''), subtitle: Text(n['created_at']?.toString() ?? '')))),
    ]));
  }
}


class VacancyListScreen extends StatefulWidget {
  const VacancyListScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<VacancyListScreen> createState() => _VacancyListScreenState();
}

class _VacancyListScreenState extends State<VacancyListScreen> {
  final api = ApiService();
  late Future<List<dynamic>> jobs = api.jobs();

  void refresh() => setState(() => jobs = api.jobs());

  Future<void> add() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) =>
      AdminCreateScreen(session: widget.session, type: 'Recruitment')));
    if (mounted) refresh();
  }

  Future<void> close(Map job) async {
    final accepted = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: Text('Close ${job['title']}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Close Vacancy')),
      ],
    ));
    if (accepted != true || !mounted) return;
    try {
      await RecruitmentHttp().closeJob(job['id'] as int);
      if (mounted) refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Open Vacancies')),
    floatingActionButton: FloatingActionButton.extended(onPressed: add,
      icon: const Icon(Icons.add), label: const Text('Vacancy')),
    body: FutureBuilder<List<dynamic>>(future: jobs, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final rows = snapshot.data!;
      if (rows.isEmpty) return const Center(child: Text('No open vacancies.'));
      return ListView(padding: const EdgeInsets.all(16), children: [
        for (final job in rows.cast<Map>())
          ListTile(title: Text('${job['title']}'), subtitle: Text('${job['department'] ?? ''}'),
            trailing: TextButton(onPressed: () => close(job), child: const Text('Close'))),
      ]);
    }),
  );
}

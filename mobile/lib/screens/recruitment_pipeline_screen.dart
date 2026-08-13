import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/recruitment_pipeline_service.dart';

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
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recruitment Pipeline'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
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

  Future<void> status(String value) async { await widget.service.setStatus(widget.application['id'] as int, value); if (mounted) Navigator.pop(context, true); }

  Future<void> addNote() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Add HR Note'), content: TextField(controller: c, maxLines: 4, decoration: const InputDecoration(hintText: 'Private note about applicant')), actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancel')), FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Save'))]));
    if (ok == true) { await widget.service.addNote(widget.application['id'] as int, c.text); await load(); }
    c.dispose();
  }

  Future<void> interview() async {
    final date = TextEditingController(text: DateTime.now().add(const Duration(days:1)).toIso8601String().substring(0,16));
    final url = TextEditingController(); final room = TextEditingController(); final note = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Schedule Interview'), content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: date, decoration: const InputDecoration(labelText: 'Date/time (YYYY-MM-DDTHH:MM)')), const SizedBox(height:8), TextField(controller: url, decoration: const InputDecoration(labelText: 'Video meeting URL')), const SizedBox(height:8), TextField(controller: room, decoration: const InputDecoration(labelText: 'Room code')), const SizedBox(height:8), TextField(controller: note, decoration: const InputDecoration(labelText: 'Interview notes'))])), actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancel')), FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Schedule'))]));
    if (ok == true) {
      await widget.service.scheduleInterview(applicationId: widget.application['id'] as int, applicantUserId: widget.application['applicant_user_id'].toString(), scheduledAt: DateTime.parse(date.text), meetingUrl: url.text, roomCode: room.text, notes: note.text);
      if (mounted) Navigator.pop(context, true);
    }
    date.dispose(); url.dispose(); room.dispose(); note.dispose();
  }

  Future<void> hire() async {
    final code = TextEditingController(); final designation = TextEditingController(); final dept = TextEditingController(); final salary = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Hire Applicant'), content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: code, decoration: const InputDecoration(labelText: 'Employee code')), const SizedBox(height:8), TextField(controller: designation, decoration: const InputDecoration(labelText: 'Designation')), const SizedBox(height:8), TextField(controller: dept, decoration: const InputDecoration(labelText: 'Department')), const SizedBox(height:8), TextField(controller: salary, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Basic salary'))])), actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancel')), FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Create Employee'))]));
    if (ok == true) {
      await widget.service.hire(applicationId: widget.application['id'] as int, employeeCode: code.text, designation: designation.text, department: dept.text, basicSalary: double.tryParse(salary.text) ?? 0);
      if (mounted) Navigator.pop(context, true);
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
      const SizedBox(height:12),
      Wrap(spacing:8, runSpacing:8, children:[OutlinedButton.icon(onPressed: ()=>status('rejected'), icon: const Icon(Icons.close), label: const Text('Reject')), OutlinedButton.icon(onPressed: ()=>status('shortlisted'), icon: const Icon(Icons.star_outline), label: const Text('Shortlist')), FilledButton.icon(onPressed: interview, icon: const Icon(Icons.video_call_outlined), label: const Text('Schedule Interview')), FilledButton.icon(onPressed: hire, icon: const Icon(Icons.badge_outlined), label: const Text('Hire & Create Employee'))]),
      const SizedBox(height:18),
      Row(children:[const Expanded(child: Text('Private HR Notes', style: TextStyle(fontSize:18,fontWeight:FontWeight.w800))), IconButton(onPressed:addNote, icon: const Icon(Icons.add_comment_outlined))]),
      if (notes.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No HR notes yet.'))) else ...notes.map((n)=>Card(child: ListTile(leading: const Icon(Icons.note_alt_outlined), title: Text(n['note']?.toString() ?? ''), subtitle: Text(n['created_at']?.toString() ?? '')))),
    ]));
  }
}

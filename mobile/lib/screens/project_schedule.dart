import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProjectSchedule extends StatefulWidget {
  const ProjectSchedule({super.key, required this.session});
  final AuthSession session;
  @override State<ProjectSchedule> createState() => _ProjectScheduleState();
}
class _ProjectScheduleState extends State<ProjectSchedule> {
  late final api = WorkspaceHttp(widget.session.token);
  late Future<List<Map<String, dynamic>>> data = api.list('/planning/tasks');
  int? projectFilter;
  bool overdueOnly = false;
  void refresh() => setState(() => data = api.list('/planning/tasks'));
  void error(Object e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  Future<void> create() async {
    try {
      final projects = await api.list('/projects');
      if (!mounted) return;
      final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _TaskForm(api: api, projects: projects)));
      if (changed == true) refresh();
    } catch (e) { error(e); }
  }
  Future<void> update(Map<String, dynamic> task) async {
    var value = (task['progress'] as num).toDouble();
    var blocked = task['status'] == 'blocked';
    final confirmed = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      title: Text('${task['title']}'), content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${value.round()}% complete', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Slider(value: value, min: 0, max: 100, divisions: 100, onChanged: (v) => setDialog(() { value = v; if (v == 100) blocked = false; })),
        CheckboxListTile(title: const Text('Blocked / waiting for action'), value: blocked, onChanged: value == 100 ? null : (v) => setDialog(() => blocked = v!)),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save progress'))],
    )));
    if (confirmed != true) return;
    try {
      await api.patch('/planning/tasks/${task['id']}/progress', {'progress': value.round(), 'status': value == 100 ? 'completed' : blocked ? 'blocked' : value == 0 ? 'planned' : 'in_progress'});
      refresh();
    } catch (e) { error(e); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Project schedule'), actions: [IconButton(onPressed: refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh))]),
    floatingActionButton: const {'owner', 'project_manager'}.contains(widget.session.role) ? FloatingActionButton.extended(onPressed: create, icon: const Icon(Icons.add), label: const Text('Task or milestone')) : null,
    body: FutureBuilder<List<Map<String, dynamic>>>(future: data, builder: (context, s) {
      if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (s.hasError) return Center(child: TextButton(onPressed: refresh, child: const Text('Could not load schedule. Retry')));
      final all = s.data!;
      final projects = <int, String>{for (final t in all) t['project_id'] as int: '${t['project_name']}'};
      final rows = all.where((t) => (projectFilter == null || t['project_id'] == projectFilter) && (!overdueOnly || t['overdue'] == true)).toList();
      final completed = all.where((t) => t['progress'] == 100).length;
      return ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 100), children: [
        Card(color: const Color(0xFF145B48), child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('From plan to handover', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
          Text('$completed of ${all.length} tasks and milestones completed', style: const TextStyle(color: Colors.white70)), const SizedBox(height: 16),
          LinearProgressIndicator(value: all.isEmpty ? 0 : completed / all.length, color: const Color(0xFF67D5B5), backgroundColor: Colors.white24),
        ]))), const SizedBox(height: 20),
        DropdownButtonFormField<int>(initialValue: projectFilter, decoration: const InputDecoration(labelText: 'Project'), items: [const DropdownMenuItem<int>(value: null, child: Text('All assigned projects')), for (final p in projects.entries) DropdownMenuItem(value: p.key, child: Text(p.value))], onChanged: (v) => setState(() => projectFilter = v)),
        const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: FilterChip(label: const Text('Overdue only'), selected: overdueOnly, onSelected: (v) => setState(() => overdueOnly = v))),
        if (rows.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Text('No tasks in this view. Add a task or milestone to start planning.')),
        for (final t in rows) Card(margin: const EdgeInsets.symmetric(vertical: 8), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(t['kind'] == 'milestone' ? Icons.flag_outlined : Icons.task_alt, color: const Color(0xFF145B48)), const SizedBox(width: 10), Expanded(child: Text('${t['title']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))), if (t['overdue'] == true) const Chip(label: Text('Overdue'), backgroundColor: Color(0xFFFFE5DB))]),
          Text('${t['project_name']} · ${t['start_date']} → ${t['due_date']}'),
          if (t['description'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${t['description']}')),
          const SizedBox(height: 16), LinearProgressIndicator(value: (t['progress'] as num) / 100, minHeight: 8, borderRadius: BorderRadius.circular(8)), const SizedBox(height: 10),
          Row(children: [Expanded(child: Text('${t['progress']}% · ${t['status'].toString().replaceAll('_', ' ')}')), TextButton(onPressed: () => update(t), child: const Text('Update progress'))]),
        ]))),
      ]);
    }),
  );
}

class _TaskForm extends StatefulWidget {
  const _TaskForm({required this.api, required this.projects});
  final WorkspaceHttp api;
  final List<Map<String, dynamic>> projects;
  @override State<_TaskForm> createState() => _TaskFormState();
}
class _TaskFormState extends State<_TaskForm> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(), description = TextEditingController();
  int? project;
  String kind = 'task';
  DateTime start = DateTime.now(), due = DateTime.now().add(const Duration(days: 7));
  bool saving = false;
  String date(DateTime d) => d.toIso8601String().split('T').first;
  @override void dispose() { title.dispose(); description.dispose(); super.dispose(); }
  Future<void> pick(bool first) async {
    final result = await showDatePicker(context: context, initialDate: first ? start : due, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (result != null) setState(() { if (first) { start = result; if (due.isBefore(start)) due = start; } else { due = result; } });
  }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (due.isBefore(DateTime(start.year, start.month, start.day))) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Due date cannot precede start date'))); return; }
    setState(() => saving = true);
    try {
      await widget.api.post('/planning/tasks', {'project_id':project, 'title':title.text.trim(), 'description':description.text.trim(), 'kind':kind, 'start_date':date(start), 'due_date':date(due)});
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    finally { if (mounted) setState(() => saving = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Plan project work')), body: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: Form(key: form, child: ListView(padding: const EdgeInsets.all(24), children: [
    DropdownButtonFormField<int>(decoration: const InputDecoration(labelText: 'Project'), items: [for (final p in widget.projects.where((p) => !['completed','cancelled'].contains(p['status']))) DropdownMenuItem(value: p['id'] as int, child: Text('${p['name']}'))], onChanged: (v) => project = v, validator: (v) => v == null ? 'Choose a project' : null), const SizedBox(height: 16),
    TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a title' : null), const SizedBox(height: 16),
    TextFormField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')), const SizedBox(height: 16),
    DropdownButtonFormField<String>(initialValue: kind, decoration: const InputDecoration(labelText: 'Work type'), items: const [DropdownMenuItem(value: 'task', child: Text('Task')), DropdownMenuItem(value: 'milestone', child: Text('Milestone'))], onChanged: (v) => kind = v!), const SizedBox(height: 16),
    OutlinedButton.icon(onPressed: () => pick(true), icon: const Icon(Icons.calendar_today), label: Text('Start: ${date(start)}')),
    OutlinedButton.icon(onPressed: () => pick(false), icon: const Icon(Icons.event), label: Text('Due: ${date(due)}')), const SizedBox(height: 24),
    FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving…' : 'Add to schedule')),
  ])))));
}

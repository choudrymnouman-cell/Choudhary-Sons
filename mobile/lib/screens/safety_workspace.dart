import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'operations_create_forms.dart';

class SafetyWorkspace extends StatefulWidget {
  const SafetyWorkspace({super.key, required this.session});
  final AuthSession session;
  @override State<SafetyWorkspace> createState() => _SafetyWorkspaceState();
}
class _SafetyWorkspaceState extends State<SafetyWorkspace> {
  late final api = WorkspaceHttp(widget.session.token);
  late Future<List<List<Map<String, dynamic>>>> data = load();
  bool closed = false;
  Future<List<List<Map<String, dynamic>>>> load() => Future.wait([api.list('/safety/incidents'), api.list('/safety/inspections')]);
  void refresh() => setState(() => data = load());
  Future<void> add(String type) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => OperationsCreateScreen(session: widget.session, type: type)));
    if (changed == true) refresh();
  }
  Future<void> close(Map<String, dynamic> incident) async {
    final action = TextEditingController();
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Close incident'), content: Form(key: form, child: TextFormField(controller: action, maxLines: 4, decoration: const InputDecoration(labelText: 'Corrective action taken'), validator: (v) => (v ?? '').trim().length < 5 ? 'Describe the action taken' : null)), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(context, true); }, child: const Text('Resolve incident'))]));
    final text = action.text.trim(); action.dispose();
    if (confirmed != true) return;
    try { await api.post('/safety/incidents/${incident['id']}/close', {'corrective_action': text}); refresh(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }
  @override Widget build(BuildContext context) => DefaultTabController(length: 2, child: Scaffold(
    appBar: AppBar(title: const Text('Quality & safety'), actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))], bottom: const TabBar(tabs: [Tab(text: 'Incidents'), Tab(text: 'Inspections')])),
    body: FutureBuilder<List<List<Map<String, dynamic>>>>(future: data, builder: (context, s) {
      if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (s.hasError) return Center(child: TextButton(onPressed: refresh, child: const Text('Could not load safety records. Retry')));
      final incidents = s.data![0].where((r) => r['is_closed'] == closed).toList();
      final inspections = s.data![1];
      return TabBarView(children: [ListView(padding: const EdgeInsets.all(24), children: [
        Wrap(spacing: 12, children: [FilledButton.icon(onPressed: () => add('Safety Incident'), icon: const Icon(Icons.add), label: const Text('Report incident')), FilterChip(label: Text(closed ? 'Closed incidents' : 'Open incidents'), selected: closed, onSelected: (v) => setState(() => closed = v))]), const SizedBox(height: 20),
        if (incidents.isEmpty) const Text('No incidents in this view.'),
        for (final i in incidents) Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i['title']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text('${i['severity']} · ${i['incident_date']}'), const SizedBox(height: 8), Text('${i['description']}'),
          if (i['corrective_action'] != null) Text('Corrective action: ${i['corrective_action']}'),
          if (!closed && const {'owner','project_manager'}.contains(widget.session.role)) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => close(i), child: const Text('Resolve and close'))),
        ]))),
      ]), ListView(padding: const EdgeInsets.all(24), children: [
        Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: () => add('Safety Inspection'), icon: const Icon(Icons.fact_check_outlined), label: const Text('New inspection'))), const SizedBox(height: 20),
        if (inspections.isEmpty) const Text('No inspections recorded yet.'),
        for (final i in inspections) Card(child: ListTile(leading: const Icon(Icons.verified_outlined), title: Text('${i['inspector']} · ${i['inspection_date']}'), subtitle: Text('Score: ${i['score'] ?? 'Not scored'} / 100\n${i['findings'] ?? ''}\nAction: ${i['action_required'] ?? 'None recorded'}'), isThreeLine: true)),
      ])]);
    }),
  ));
}

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StaffProfileForm extends StatefulWidget {
  const StaffProfileForm({super.key, required this.session});
  final AuthSession session;
  @override State<StaffProfileForm> createState() => _StaffProfileFormState();
}

class _StaffProfileFormState extends State<StaffProfileForm> {
  late final api = WorkspaceHttp(widget.session.token);
  final form = GlobalKey<FormState>();
  final code = TextEditingController();
  final designation = TextEditingController();
  final department = TextEditingController();
  final salary = TextEditingController(text: '0');
  late Future<List<List<Map<String, dynamic>>>> data = load();
  int? userId, projectId;
  DateTime joined = DateTime.now();
  bool saving = false;
  Future<List<List<Map<String, dynamic>>>> load() => Future.wait([
    api.list('/employees/unlinked-accounts'), api.list('/projects'),
  ]);
  @override void dispose() {
    for (final c in [code, designation, department, salary]) { c.dispose(); }
    super.dispose();
  }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await api.post('/employees/link-account', {
        'user_id': userId, 'employee_code': code.text.trim(),
        'designation': designation.text.trim(), 'department': department.text.trim(),
        'joining_date': joined.toIso8601String().split('T').first,
        'basic_salary': salary.text.trim(), 'project_id': projectId,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => saving = false); }
  }
  Widget field(TextEditingController c, String label, {bool money = false, bool required = true}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(controller: c, keyboardType: money ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label), validator: (v) {
        if (required && (v ?? '').trim().isEmpty) return 'Enter $label';
        if (money && (double.tryParse(v ?? '') == null || double.parse(v!) < 0)) return 'Enter a valid non-negative amount';
        return null;
      }),
  );
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add employee profile')),
    body: FutureBuilder<List<List<Map<String, dynamic>>>>(future: data, builder: (context, s) {
      if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (s.hasError) return Center(child: TextButton(onPressed: () => setState(() => data = load()), child: const Text('Could not load accounts. Retry')));
      final accounts = s.data![0], projects = s.data![1];
      if (accounts.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No approved accounts need a profile. Ask the owner to assign a role to the staff signup in Owner console → Accounts.')));
      return Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: Form(key: form, child: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Connect a staff account to HR', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8), const Text('Their password and owner-assigned permissions stay the same.'), const SizedBox(height: 24),
        DropdownButtonFormField<int>(isExpanded: true, decoration: const InputDecoration(labelText: 'Approved account'), items: [for (final a in accounts) DropdownMenuItem(value: a['id'] as int, child: Text('${a['full_name']} · ${a['email']}', overflow: TextOverflow.ellipsis))], onChanged: (v) => userId = v, validator: (v) => v == null ? 'Choose an account' : null),
        const SizedBox(height: 16), field(code, 'Employee code'), field(designation, 'Designation'), field(department, 'Department', required: false), field(salary, 'Monthly basic salary', money: true),
        DropdownButtonFormField<int>(decoration: const InputDecoration(labelText: 'Work site (optional)'), items: [const DropdownMenuItem<int>(value: null, child: Text('Head office / unassigned')), for (final p in projects) DropdownMenuItem(value: p['id'] as int, child: Text('${p['name']}'))], onChanged: (v) => projectId = v),
        const SizedBox(height: 16), OutlinedButton.icon(icon: const Icon(Icons.calendar_month), label: Text('Joining date: ${joined.toIso8601String().split('T').first}'), onPressed: () async {
          final date = await showDatePicker(context: context, initialDate: joined, firstDate: DateTime(1970), lastDate: DateTime.now().add(const Duration(days: 366)));
          if (date != null) setState(() => joined = date);
        }), const SizedBox(height: 24), FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving…' : 'Create employee profile')),
      ]))));
    }),
  );
}

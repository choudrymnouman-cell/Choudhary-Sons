import 'package:flutter/material.dart';

import '../services/api_service.dart';

class EmployeeDataScreen extends StatelessWidget {
  const EmployeeDataScreen({super.key, required this.session, required this.type});
  final AuthSession session;
  final String type;

  Future<dynamic> _load() {
    final api = ApiService();
    switch (type) {
      case 'My Profile': return api.myEmployeeProfile(session.token);
      case 'Attendance History': return api.myAttendance(session.token);
      case 'Salary & Payslips': return api.myPayroll(session.token);
      case 'Leave Requests': return api.myLeave(session.token);
      case 'Open Jobs': return api.jobs();
      case 'Notices': return api.notices(session.token);
      default: return Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(type)),
      floatingActionButton: type == 'Leave Requests'
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeaveRequestScreen(session: session))),
              icon: const Icon(Icons.add),
              label: const Text('Apply'),
            )
          : null,
      body: FutureBuilder<dynamic>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString().replaceFirst('Exception: ', '')));
          final data = snapshot.data;
          if (data is Map<String, dynamic>) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: data.entries.map((e) => Card(child: ListTile(title: Text(e.key.replaceAll('_', ' ')), subtitle: Text('${e.value ?? '-'}')))).toList(),
            );
          }
          final rows = (data as List<dynamic>? ?? const []);
          if (rows.isEmpty) return const Center(child: Text('No records yet.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final item = Map<String, dynamic>.from(rows[index] as Map);
              final title = (item['title'] ?? item['period'] ?? item['date'] ?? item['leave_type'] ?? 'Record').toString();
              final detail = item.entries.where((e) => e.key != 'id' && e.key != 'title').take(4).map((e) => '${e.key.replaceAll('_', ' ')}: ${e.value}').join('\n');
              return Card(child: ListTile(title: Text(title), subtitle: Text(detail)));
            },
          );
        },
      ),
    );
  }
}

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key, required this.session});
  final AuthSession session;

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final _api = ApiService();
  final _reason = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  String _type = 'annual';
  bool _saving = false;

  String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _pick(bool start) async {
    final selected = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)), initialDate: DateTime.now());
    if (selected != null) setState(() => start ? _start = selected : _end = selected);
  }

  Future<void> _submit() async {
    if (_start == null || _end == null) return;
    setState(() => _saving = true);
    try {
      await _api.requestLeave(token: widget.session.token, leaveType: _type, startDate: _date(_start!), endDate: _date(_end!), reason: _reason.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave request submitted')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Leave')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            value: _type,
            items: const ['annual', 'sick', 'casual', 'unpaid'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _type = v ?? 'annual'),
            decoration: const InputDecoration(labelText: 'Leave type', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          ListTile(title: const Text('Start date'), subtitle: Text(_start == null ? 'Select date' : _date(_start!)), trailing: const Icon(Icons.calendar_month), onTap: () => _pick(true)),
          ListTile(title: const Text('End date'), subtitle: Text(_end == null ? 'Select date' : _date(_end!)), trailing: const Icon(Icons.calendar_month), onTap: () => _pick(false)),
          const SizedBox(height: 14),
          TextField(controller: _reason, maxLines: 4, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving || _start == null || _end == null ? null : _submit, child: Text(_saving ? 'Submitting...' : 'Submit Request')),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'admin_create_forms.dart';

class ManagementListScreen extends StatefulWidget {
  const ManagementListScreen({super.key, required this.session, required this.type});
  final AuthSession session;
  final String type;

  @override
  State<ManagementListScreen> createState() => _ManagementListScreenState();
}

class _ManagementListScreenState extends State<ManagementListScreen> {
  final _api = ApiService();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() {
    switch (widget.type) {
      case 'Projects': return _api.projects(widget.session.token);
      case 'Employees': return _api.employees(widget.session.token);
      case 'Attendance': return _api.attendance(widget.session.token);
      case 'Payroll': return _api.payroll(widget.session.token);
      case 'Recruitment': return _api.jobApplications(widget.session.token);
      case 'Leave': return _api.leaveRequests(widget.session.token);
      default: return Future.value([]);
    }
  }

  void _refresh() => setState(() => _future = _load());

  String _title(Map<String, dynamic> item) {
    return (item['name'] ?? item['full_name'] ?? item['employee_code'] ?? item['applicant_name'] ?? item['period'] ?? (item['employee_id'] != null ? 'Employee ${item['employee_id']}' : widget.type)).toString();
  }

  String _subtitle(Map<String, dynamic> item) {
    final fields = <String>[
      if (item['code'] != null) 'Code: ${item['code']}',
      if (item['designation'] != null) item['designation'].toString(),
      if (item['department'] != null) item['department'].toString(),
      if (item['date'] != null) 'Date: ${item['date']}',
      if (item['start_date'] != null) '${item['start_date']} → ${item['end_date']}',
      if (item['status'] != null) 'Status: ${item['status']}',
      if (item['email'] != null) item['email'].toString(),
      if (item['net_salary'] != null) 'Net salary: ${item['net_salary']}',
      if (item['contract_value'] != null) 'Contract: ${item['contract_value']}',
    ];
    return fields.take(3).join(' • ');
  }

  Future<void> _add() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AdminCreateScreen(session: widget.session, type: widget.type)));
    if (changed == true) _refresh();
  }

  Future<void> _reviewLeave(int id, String decision) async {
    try {
      await _api.reviewLeave(widget.session.token, id, decision);
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  bool get _canAdd => const {'Projects','Employees','Payroll','Recruitment'}.contains(widget.type);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.type)),
      floatingActionButton: _canAdd ? FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add')) : null,
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString().replaceFirst('Exception: ', '')));
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) return Center(child: Text('No ${widget.type.toLowerCase()} records yet.'));
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16,16,16,90),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = Map<String, dynamic>.from(rows[index] as Map);
                final pendingLeave = widget.type == 'Leave' && item['status'].toString().toLowerCase().contains('pending');
                return Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(child: Text(_title(item).isEmpty ? '?' : _title(item)[0].toUpperCase())),
                        title: Text(_title(item)),
                        subtitle: Text(_subtitle(item)),
                      ),
                      if (pendingLeave)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16,0,16,12),
                          child: Row(children: [
                            Expanded(child: OutlinedButton.icon(onPressed: () => _reviewLeave(item['id'] as int, 'rejected'), icon: const Icon(Icons.close), label: const Text('Reject'))),
                            const SizedBox(width: 10),
                            Expanded(child: FilledButton.icon(onPressed: () => _reviewLeave(item['id'] as int, 'approved'), icon: const Icon(Icons.check), label: const Text('Approve'))),
                          ]),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

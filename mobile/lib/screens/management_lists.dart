import 'package:flutter/material.dart';

import '../services/api_service.dart';

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
      default: return Future.value([]);
    }
  }

  String _title(Map<String, dynamic> item) {
    return (item['name'] ?? item['full_name'] ?? item['employee_code'] ?? item['applicant_name'] ?? item['period'] ?? widget.type).toString();
  }

  String _subtitle(Map<String, dynamic> item) {
    final fields = <String>[
      if (item['code'] != null) 'Code: ${item['code']}',
      if (item['designation'] != null) item['designation'].toString(),
      if (item['department'] != null) item['department'].toString(),
      if (item['date'] != null) 'Date: ${item['date']}',
      if (item['status'] != null) 'Status: ${item['status']}',
      if (item['email'] != null) item['email'].toString(),
      if (item['net_salary'] != null) 'Net salary: ${item['net_salary']}',
      if (item['contract_value'] != null) 'Contract: ${item['contract_value']}',
    ];
    return fields.take(3).join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.type)),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString().replaceFirst('Exception: ', '')));
          }
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) return Center(child: Text('No ${widget.type.toLowerCase()} records yet.'));
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = Map<String, dynamic>.from(rows[index] as Map);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(_title(item).isEmpty ? '?' : _title(item)[0].toUpperCase())),
                    title: Text(_title(item)),
                    subtitle: Text(_subtitle(item)),
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

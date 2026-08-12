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
  final _search = TextEditingController();
  late Future<List<dynamic>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
    return (item['name'] ?? item['full_name'] ?? item['employee_code'] ?? item['applicant_name'] ?? item['period'] ?? item['leave_type'] ?? (item['employee_id'] != null ? 'Employee ${item['employee_id']}' : widget.type)).toString();
  }

  String _subtitle(Map<String, dynamic> item) {
    final fields = <String>[
      if (item['code'] != null) 'Code: ${item['code']}',
      if (item['designation'] != null) item['designation'].toString(),
      if (item['department'] != null) item['department'].toString(),
      if (item['is_active'] != null) item['is_active'] == true ? 'Active' : 'Inactive',
      if (item['date'] != null) 'Date: ${item['date']}',
      if (item['start_date'] != null) '${item['start_date']} → ${item['end_date'] ?? ''}',
      if (item['status'] != null) 'Status: ${item['status']}',
      if (item['email'] != null) item['email'].toString(),
      if (item['net_salary'] != null) 'Net salary: ${item['net_salary']}',
      if (item['contract_value'] != null) 'Contract: ${item['contract_value']}',
    ];
    return fields.take(3).join(' • ');
  }

  bool _matches(Map<String, dynamic> item) {
    if (_query.isEmpty) return true;
    return item.values.where((value) => value != null).join(' ').toLowerCase().contains(_query.toLowerCase());
  }

  Future<void> _add() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminCreateScreen(session: widget.session, type: widget.type)),
    );
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

  Future<void> _edit(Map<String, dynamic> item) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => EditRecordScreen(session: widget.session, type: widget.type, record: item),
    ));
    if (changed == true) _refresh();
  }

  Future<void> _deactivateEmployee(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate employee?'),
        content: Text('${item['full_name'] ?? item['employee_code']} will no longer be able to sign in. Attendance and payroll history will be kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deactivateEmployee(widget.session.token, item['id'] as int);
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee deactivated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  bool get _canAdd => const {'Projects', 'Employees', 'Payroll', 'Recruitment'}.contains(widget.type);
  bool get _canEdit => const {'Projects', 'Employees'}.contains(widget.type);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type == 'Leave' ? 'Leave Management' : widget.type),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: _canAdd ? FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add')) : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: 'Search ${widget.type.toLowerCase()}...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text(snapshot.error.toString().replaceFirst('Exception: ', '')));
                final rows = (snapshot.data ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).where(_matches).toList();
                if (rows.isEmpty) return Center(child: Text(_query.isEmpty ? 'No ${widget.type.toLowerCase()} records yet.' : 'No matching records.'));
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = rows[index];
                      final pendingLeave = widget.type == 'Leave' && item['status'].toString().toLowerCase().contains('pending');
                      final employeeActive = item['is_active'] != false;
                      return Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(child: Text(_title(item).isEmpty ? '?' : _title(item)[0].toUpperCase())),
                              title: Text(_title(item)),
                              subtitle: Text(_subtitle(item)),
                              trailing: _canEdit
                                  ? PopupMenuButton<String>(
                                      onSelected: (action) {
                                        if (action == 'edit') _edit(item);
                                        if (action == 'deactivate') _deactivateEmployee(item);
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'), contentPadding: EdgeInsets.zero)),
                                        if (widget.type == 'Employees' && employeeActive)
                                          const PopupMenuItem(value: 'deactivate', child: ListTile(leading: Icon(Icons.person_off_outlined), title: Text('Deactivate'), contentPadding: EdgeInsets.zero)),
                                      ],
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => RecordDetailScreen(title: _title(item), record: item)),
                              ),
                            ),
                            if (pendingLeave)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
          ),
        ],
      ),
    );
  }
}

class EditRecordScreen extends StatefulWidget {
  const EditRecordScreen({super.key, required this.session, required this.type, required this.record});
  final AuthSession session;
  final String type;
  final Map<String, dynamic> record;

  @override
  State<EditRecordScreen> createState() => _EditRecordScreenState();
}

class _EditRecordScreenState extends State<EditRecordScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;
  String? _projectStatus;

  TextEditingController _controller(String key) => _controllers.putIfAbsent(key, () => TextEditingController(text: '${widget.record[key] ?? ''}'));

  @override
  void initState() {
    super.initState();
    if (widget.type == 'Projects') _projectStatus = widget.record['status']?.toString();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, String label, {bool number = false, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: _controller(key),
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          maxLines: lines,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = widget.record['id'] as int;
      if (widget.type == 'Projects') {
        await _api.updateProject(widget.session.token, id, {
          'name': _controller('name').text.trim(),
          'description': _controller('description').text.trim().isEmpty ? null : _controller('description').text.trim(),
          'site_address': _controller('site_address').text.trim().isEmpty ? null : _controller('site_address').text.trim(),
          'contract_value': double.tryParse(_controller('contract_value').text.trim()),
          'start_date': _controller('start_date').text.trim().isEmpty ? null : _controller('start_date').text.trim(),
          'end_date': _controller('end_date').text.trim().isEmpty ? null : _controller('end_date').text.trim(),
          'status': _projectStatus,
        });
      } else if (widget.type == 'Employees') {
        await _api.updateEmployee(widget.session.token, id, {
          'full_name': _controller('full_name').text.trim(),
          'phone': _controller('phone').text.trim().isEmpty ? null : _controller('phone').text.trim(),
          'designation': _controller('designation').text.trim(),
          'department': _controller('department').text.trim().isEmpty ? null : _controller('department').text.trim(),
          'basic_salary': double.tryParse(_controller('basic_salary').text.trim()),
          'cnic': _controller('cnic').text.trim().isEmpty ? null : _controller('cnic').text.trim(),
          'emergency_contact': _controller('emergency_contact').text.trim().isEmpty ? null : _controller('emergency_contact').text.trim(),
          'address': _controller('address').text.trim().isEmpty ? null : _controller('address').text.trim(),
        });
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.type == 'Projects';
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${project ? 'Project' : 'Employee'}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: project
              ? [
                  _field('name', 'Project name'),
                  _field('description', 'Description', lines: 3),
                  _field('site_address', 'Site address', lines: 2),
                  _field('contract_value', 'Contract value', number: true),
                  _field('start_date', 'Start date (YYYY-MM-DD)'),
                  _field('end_date', 'End date (YYYY-MM-DD)'),
                  DropdownButtonFormField<String>(
                    initialValue: _projectStatus,
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                    items: const ['planned', 'active', 'on_hold', 'completed', 'cancelled'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => _projectStatus = v,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving...' : 'Save changes')),
                ]
              : [
                  _field('full_name', 'Full name'),
                  _field('phone', 'Phone'),
                  _field('designation', 'Designation'),
                  _field('department', 'Department'),
                  _field('basic_salary', 'Basic salary', number: true),
                  _field('cnic', 'CNIC'),
                  _field('emergency_contact', 'Emergency contact'),
                  _field('address', 'Address', lines: 3),
                  const SizedBox(height: 8),
                  FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving...' : 'Save changes')),
                ],
        ),
      ),
    );
  }
}

class RecordDetailScreen extends StatelessWidget {
  const RecordDetailScreen({super.key, required this.title, required this.record});
  final String title;
  final Map<String, dynamic> record;

  String _label(String key) {
    return key.split('_').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final entries = record.entries.where((entry) => entry.value != null).toList();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ListTile(
            title: Text(_label(entry.key), style: Theme.of(context).textTheme.labelLarge),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText('${entry.value}'),
            ),
          );
        },
      ),
    );
  }
}

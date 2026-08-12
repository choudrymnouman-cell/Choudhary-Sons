import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AdminCreateScreen extends StatefulWidget {
  const AdminCreateScreen({super.key, required this.session, required this.type});
  final AuthSession session;
  final String type;

  @override
  State<AdminCreateScreen> createState() => _AdminCreateScreenState();
}

class _AdminCreateScreenState extends State<AdminCreateScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {};
  bool _saving = false;

  TextEditingController ctrl(String key) => _c.putIfAbsent(key, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _c.values) c.dispose();
    super.dispose();
  }

  List<Widget> _fields() {
    switch (widget.type) {
      case 'Projects':
        return [_field('code','Project code'), _field('name','Project / contract name'), _field('site_address','Site address'), _field('contract_value','Contract value', number: true), _field('description','Description', lines: 3)];
      case 'Employees':
        return [_field('full_name','Full name'), _field('email','Email'), _field('phone','Phone'), _field('password','Temporary password', secret: true), _field('employee_code','Employee code'), _field('designation','Designation'), _field('department','Department'), _field('joining_date','Joining date (YYYY-MM-DD)'), _field('basic_salary','Basic salary', number: true)];
      case 'Payroll':
        return [_field('employee_id','Employee ID', number: true), _field('period','Period (YYYY-MM)'), _field('basic_salary','Basic salary', number: true), _field('overtime','Overtime', number: true), _field('allowances','Allowances', number: true), _field('deductions','Deductions', number: true), _field('advances','Advances', number: true), _field('notes','Notes', lines: 2)];
      case 'Recruitment':
        return [_field('title','Job title'), _field('department','Department'), _field('location','Location'), _field('employment_type','Employment type'), _field('salary_min','Minimum salary', number: true), _field('salary_max','Maximum salary', number: true), _field('description','Job description', lines: 4)];
      default:
        return const [];
    }
  }

  Widget _field(String key, String label, {bool number = false, bool secret = false, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl(key),
        obscureText: secret,
        maxLines: secret ? 1 : lines,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (value) {
          const required = {'code','name','full_name','email','password','employee_code','designation','joining_date','employee_id','period','basic_salary','title','description'};
          if (required.contains(key) && (value == null || value.trim().isEmpty)) return '$label is required';
          return null;
        },
      ),
    );
  }

  double numValue(String key) => double.tryParse(ctrl(key).text.trim()) ?? 0;
  int intValue(String key) => int.tryParse(ctrl(key).text.trim()) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final token = widget.session.token;
      switch (widget.type) {
        case 'Projects':
          await _api.createProject(token, {'code': ctrl('code').text.trim(), 'name': ctrl('name').text.trim(), 'site_address': ctrl('site_address').text.trim(), 'contract_value': numValue('contract_value'), 'description': ctrl('description').text.trim()});
          break;
        case 'Employees':
          await _api.createEmployee(token, {'full_name': ctrl('full_name').text.trim(), 'email': ctrl('email').text.trim(), 'phone': ctrl('phone').text.trim().isEmpty ? null : ctrl('phone').text.trim(), 'password': ctrl('password').text, 'employee_code': ctrl('employee_code').text.trim(), 'designation': ctrl('designation').text.trim(), 'department': ctrl('department').text.trim().isEmpty ? null : ctrl('department').text.trim(), 'joining_date': ctrl('joining_date').text.trim(), 'basic_salary': numValue('basic_salary'), 'role': 'employee'});
          break;
        case 'Payroll':
          await _api.createPayroll(token, {'employee_id': intValue('employee_id'), 'period': ctrl('period').text.trim(), 'basic_salary': numValue('basic_salary'), 'overtime': numValue('overtime'), 'allowances': numValue('allowances'), 'deductions': numValue('deductions'), 'advances': numValue('advances'), 'notes': ctrl('notes').text.trim().isEmpty ? null : ctrl('notes').text.trim()});
          break;
        case 'Recruitment':
          await _api.createJob(token, {'title': ctrl('title').text.trim(), 'department': ctrl('department').text.trim().isEmpty ? null : ctrl('department').text.trim(), 'location': ctrl('location').text.trim().isEmpty ? null : ctrl('location').text.trim(), 'employment_type': ctrl('employment_type').text.trim().isEmpty ? 'full_time' : ctrl('employment_type').text.trim(), 'salary_min': ctrl('salary_min').text.trim().isEmpty ? null : numValue('salary_min'), 'salary_max': ctrl('salary_max').text.trim().isEmpty ? null : numValue('salary_max'), 'description': ctrl('description').text.trim()});
          break;
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add ${widget.type == 'Recruitment' ? 'Job Vacancy' : widget.type == 'Payroll' ? 'Payroll Record' : widget.type.substring(0, widget.type.length - 1)}')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [..._fields(), const SizedBox(height: 8), FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.save), label: Text(_saving ? 'Saving...' : 'Save'))]),
      ),
    );
  }
}

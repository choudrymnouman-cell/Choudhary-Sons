import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthSession {
  final String token;
  final String userId;
  final String fullName;
  final String email;
  final String role;

  const AuthSession({required this.token, required this.userId, required this.fullName, required this.email, required this.role});

  bool get isManagement => const {'owner', 'admin', 'hr', 'accountant', 'project_manager', 'site_supervisor'}.contains(role);
}

class ApiService {
  SupabaseClient get _db => Supabase.instance.client;
  User get _user {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Please sign in again.');
    return user;
  }

  Future<AuthSession> login(String email, String password) async {
    final response = await _db.auth.signInWithPassword(email: email.trim(), password: password);
    final user = response.user;
    final session = response.session;
    if (user == null || session == null) throw Exception('Login failed');
    final profile = Map<String, dynamic>.from(await _db.from('profiles').select().eq('id', user.id).single());
    if (profile['is_active'] == false) {
      await _db.auth.signOut();
      throw Exception('This account is inactive. Contact management.');
    }
    return AuthSession(token: session.accessToken, userId: user.id, fullName: (profile['full_name'] ?? user.email ?? 'User').toString(), email: (profile['email'] ?? user.email ?? '').toString(), role: (profile['role'] ?? 'employee').toString());
  }

  Future<void> signOut() => _db.auth.signOut();

  Future<Map<String, dynamic>> myEmployeeProfile(String token) async {
    final raw = await _db.from('employees').select('*, profiles(full_name,email,phone,role,is_active)').eq('user_id', _user.id).single();
    return _flattenEmployee(Map<String, dynamic>.from(raw));
  }

  Future<List<dynamic>> employees(String token) async {
    final rows = await _db.from('employees').select('*, profiles(full_name,email,phone,role,is_active)').order('employee_code');
    return (rows as List).map((e) => _flattenEmployee(Map<String, dynamic>.from(e as Map))).toList();
  }

  Map<String, dynamic> _flattenEmployee(Map<String, dynamic> row) {
    final profile = row.remove('profiles');
    if (profile is Map) row.addAll(Map<String, dynamic>.from(profile));
    return row;
  }

  Future<List<dynamic>> attendance(String token) async => _attendanceRows();
  Future<List<dynamic>> myAttendance(String token) async => _attendanceRows();
  Future<List<dynamic>> _attendanceRows() async {
    final rows = await _db.from('attendance').select().order('attendance_date', ascending: false);
    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      m['date'] = m['attendance_date'];
      return m;
    }).toList();
  }

  Future<void> checkIn(String token) async => _db.rpc('check_in');
  Future<void> checkOut(String token) async => _db.rpc('check_out');

  Future<List<dynamic>> projects(String token) async => List<dynamic>.from(await _db.from('projects').select().order('created_at', ascending: false));
  Future<Map<String, dynamic>> createProject(String token, Map<String, dynamic> body) => _insert('projects', _withoutNulls(body));
  Future<Map<String, dynamic>> updateProject(String token, int id, Map<String, dynamic> body) => _update('projects', id, _withoutNulls(body));

  Future<List<dynamic>> payroll(String token) async => List<dynamic>.from(await _db.from('payroll_records').select().order('created_at', ascending: false));
  Future<List<dynamic>> myPayroll(String token) async => List<dynamic>.from(await _db.from('payroll_records').select().order('created_at', ascending: false));
  Future<Map<String, dynamic>> createPayroll(String token, Map<String, dynamic> body) => _insert('payroll_records', _withoutNulls(body)..remove('net_salary'));

  Future<List<dynamic>> jobs() async => List<dynamic>.from(await _db.from('job_vacancies').select().eq('is_open', true).order('created_at', ascending: false));
  Future<List<dynamic>> jobApplications(String token) async => List<dynamic>.from(await _db.from('job_applications').select().order('created_at', ascending: false));
  Future<Map<String, dynamic>> createJob(String token, Map<String, dynamic> body) => _insert('job_vacancies', _withoutNulls(body));

  Future<List<dynamic>> myLeave(String token) async => List<dynamic>.from(await _db.from('leave_requests').select().order('created_at', ascending: false));
  Future<List<dynamic>> leaveRequests(String token) async => List<dynamic>.from(await _db.from('leave_requests').select().order('created_at', ascending: false));

  Future<void> requestLeave({required String token, required String leaveType, required String startDate, required String endDate, String? reason}) async {
    final employee = await _db.from('employees').select('id').eq('user_id', _user.id).single();
    await _db.from('leave_requests').insert({'employee_id': employee['id'], 'leave_type': leaveType, 'start_date': startDate, 'end_date': endDate, 'reason': reason});
  }

  Future<void> reviewLeave(String token, int id, String decision) async {
    await _db.from('leave_requests').update({'status': decision, 'reviewed_by': _user.id, 'reviewed_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<Map<String, dynamic>> createEmployee(String token, Map<String, dynamic> body) async {
    final response = await _db.functions.invoke('create-employee', body: body);
    if (response.status < 200 || response.status >= 300) throw Exception(_functionError(response.data));
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updateEmployee(String token, int id, Map<String, dynamic> body) async {
    final existing = Map<String, dynamic>.from(await _db.from('employees').select('user_id').eq('id', id).single());
    final employeeBody = <String, dynamic>{};
    for (final key in ['designation', 'department', 'basic_salary', 'cnic', 'emergency_contact', 'address']) {
      if (body.containsKey(key)) employeeBody[key] = body[key];
    }
    if (employeeBody.isNotEmpty) await _db.from('employees').update(employeeBody).eq('id', id);
    final profileBody = <String, dynamic>{};
    for (final key in ['full_name', 'phone']) {
      if (body.containsKey(key)) profileBody[key] = body[key];
    }
    if (profileBody.isNotEmpty) await _db.from('profiles').update(profileBody).eq('id', existing['user_id']);
    return _flattenEmployee(Map<String, dynamic>.from(await _db.from('employees').select('*, profiles(full_name,email,phone,role,is_active)').eq('id', id).single()));
  }

  Future<void> deactivateEmployee(String token, int id) async {
    final row = await _db.from('employees').select('user_id').eq('id', id).single();
    await _db.from('profiles').update({'is_active': false}).eq('id', row['user_id']);
  }

  Future<List<dynamic>> suppliers(String token) async => List<dynamic>.from(await _db.from('suppliers').select().order('name'));
  Future<List<dynamic>> materials(String token) async => List<dynamic>.from(await _db.from('materials').select().order('name'));
  Future<List<dynamic>> lowStockMaterials(String token) async {
    final rows = List<dynamic>.from(await _db.from('materials').select().order('name'));
    return rows.where((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return _num(m['quantity_on_hand']) <= _num(m['reorder_level']);
    }).toList();
  }
  Future<List<dynamic>> purchaseOrders(String token) async => List<dynamic>.from(await _db.from('purchase_orders').select().order('created_at', ascending: false));
  Future<List<dynamic>> expenses(String token) async => List<dynamic>.from(await _db.from('expenses').select().order('expense_date', ascending: false));
  Future<List<dynamic>> invoices(String token) async => List<dynamic>.from(await _db.from('client_invoices').select().order('invoice_date', ascending: false));

  Future<Map<String, dynamic>> createSupplier(String token, Map<String, dynamic> body) => _insert('suppliers', _withoutNulls(body));
  Future<Map<String, dynamic>> createMaterial(String token, Map<String, dynamic> body) => _insert('materials', _withoutNulls(body));
  Future<Map<String, dynamic>> createPurchaseOrder(String token, Map<String, dynamic> body) => _insert('purchase_orders', _withoutNulls(body));
  Future<Map<String, dynamic>> createExpense(String token, Map<String, dynamic> body) => _insert('expenses', _withoutNulls(body));
  Future<Map<String, dynamic>> createInvoice(String token, Map<String, dynamic> body) {
    final clean = _withoutNulls(body);
    clean['total_amount'] = _num(clean['amount']) + _num(clean['tax_amount']);
    final paid = _num(clean['paid_amount']);
    final total = _num(clean['total_amount']);
    clean['status'] = paid <= 0 ? 'unpaid' : paid >= total ? 'paid' : 'partial';
    return _insert('client_invoices', clean);
  }

  Future<List<dynamic>> assets(String token) async => List<dynamic>.from(await _db.from('assets').select().order('created_at', ascending: false));
  Future<List<dynamic>> siteReports(String token) async => List<dynamic>.from(await _db.from('site_daily_reports').select().order('report_date', ascending: false));
  Future<List<dynamic>> safetyIncidents(String token) async => List<dynamic>.from(await _db.from('safety_incidents').select().order('incident_date', ascending: false));
  Future<List<dynamic>> notices(String token) async => List<dynamic>.from(await _db.from('notices').select().eq('is_active', true).order('created_at', ascending: false));

  Future<Map<String, dynamic>> createAsset(String token, Map<String, dynamic> body) => _insert('assets', _withoutNulls(body));
  Future<Map<String, dynamic>> createFuelLog(String token, Map<String, dynamic> body) => _insert('fuel_logs', _withoutNulls(body));
  Future<Map<String, dynamic>> createMaintenance(String token, Map<String, dynamic> body) => _insert('maintenance_logs', _withoutNulls(body));
  Future<Map<String, dynamic>> createSiteReport(String token, Map<String, dynamic> body) => _insert('site_daily_reports', _withoutNulls({...body, 'submitted_by': _user.id}));
  Future<Map<String, dynamic>> createSafetyIncident(String token, Map<String, dynamic> body) => _insert('safety_incidents', _withoutNulls({...body, 'reported_by': _user.id}));
  Future<Map<String, dynamic>> createNotice(String token, Map<String, dynamic> body) => _insert('notices', _withoutNulls({...body, 'created_by': _user.id}));

  Future<List<dynamic>> documents(String token, {int? projectId, int? employeeId}) async {
    var query = _db.from('company_documents').select();
    if (projectId != null) query = query.eq('project_id', projectId);
    if (employeeId != null) query = query.eq('employee_id', employeeId);
    return List<dynamic>.from(await query.order('created_at', ascending: false));
  }

  Future<Map<String, dynamic>> documentDownloadUrl(String token, int documentId) async {
    final doc = Map<String, dynamic>.from(await _db.from('company_documents').select('storage_path').eq('id', documentId).single());
    final url = await _db.storage.from('company-documents').createSignedUrl(doc['storage_path'].toString(), 600);
    return {'url': url, 'expires_in': 600};
  }

  Future<Map<String, dynamic>> uploadDocument({required String token, required String title, required String documentType, required String fileName, required Uint8List bytes, int? projectId, int? employeeId, String? expiryDate}) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '${_user.id}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _db.storage.from('company-documents').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));
    try {
      return await _insert('company_documents', _withoutNulls({'project_id': projectId, 'employee_id': employeeId, 'title': title, 'document_type': documentType, 'storage_path': path, 'expiry_date': expiryDate, 'uploaded_by': _user.id}));
    } catch (_) {
      await _db.storage.from('company-documents').remove([path]);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> dashboardKpis(String token) async {
    final projectRows = List<dynamic>.from(await _db.from('projects').select('status'));
    final employeeRows = List<dynamic>.from(await _db.from('employees').select('id'));
    final incidentRows = List<dynamic>.from(await _db.from('safety_incidents').select('is_closed'));
    final leaveRows = List<dynamic>.from(await _db.from('leave_requests').select('status'));
    return {'active_projects': projectRows.where((e) => (e as Map)['status'] == 'active').length, 'employees': employeeRows.length, 'open_safety_incidents': incidentRows.where((e) => (e as Map)['is_closed'] != true).length, 'pending_leave': leaveRows.where((e) => (e as Map)['status'] == 'pending').length};
  }

  Future<Map<String, dynamic>> assetCostSummary(String token) async {
    final assetRows = List<dynamic>.from(await _db.from('assets').select('id'));
    final fuelRows = List<dynamic>.from(await _db.from('fuel_logs').select('total_cost'));
    final maintenanceRows = List<dynamic>.from(await _db.from('maintenance_logs').select('cost'));
    return {'asset_count': assetRows.length, 'fuel_cost': fuelRows.fold<double>(0, (sum, e) => sum + _num((e as Map)['total_cost'])), 'maintenance_cost': maintenanceRows.fold<double>(0, (sum, e) => sum + _num((e as Map)['cost']))};
  }

  Future<Map<String, dynamic>> projectProfitability(String token, int projectId) async => Map<String, dynamic>.from(await _db.from('project_profitability').select().eq('project_id', projectId).single());

  Future<Map<String, dynamic>> _insert(String table, Map<String, dynamic> body) async => Map<String, dynamic>.from(await _db.from(table).insert(body).select().single());
  Future<Map<String, dynamic>> _update(String table, int id, Map<String, dynamic> body) async => Map<String, dynamic>.from(await _db.from(table).update(body).eq('id', id).select().single());
  Map<String, dynamic> _withoutNulls(Map<String, dynamic> source) => Map<String, dynamic>.fromEntries(source.entries.where((e) => e.value != null));
  double _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  String _functionError(dynamic data) => data is Map && data['error'] != null ? data['error'].toString() : 'Request failed';
}

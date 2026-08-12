import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthSession {
  final String token;
  final int userId;
  final String fullName;
  final String email;
  final String role;

  const AuthSession({required this.token, required this.userId, required this.fullName, required this.email, required this.role});

  bool get isManagement => const {'owner','admin','hr','accountant','project_manager','site_supervisor'}.contains(role);
}

class ApiService {
  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');
  final String baseUrl;

  Map<String, String> _authHeaders(String token) => {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

  Future<AuthSession> login(String email, String password) async {
    final response = await http.post(Uri.parse('$baseUrl/api/v1/auth/login'), headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: {'username': email.trim(), 'password': password});
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) throw Exception(payload['detail'] ?? 'Login failed');
    final user = payload['user'] as Map<String, dynamic>;
    return AuthSession(token: payload['access_token'], userId: user['id'], fullName: user['full_name'], email: user['email'], role: user['role']);
  }

  Future<Map<String, dynamic>> myEmployeeProfile(String token) => _getMap('/api/v1/employees/me', token);
  Future<List<dynamic>> employees(String token) => _getList('/api/v1/employees', token);
  Future<List<dynamic>> attendance(String token) => _getList('/api/v1/attendance', token);
  Future<List<dynamic>> myAttendance(String token) => _getList('/api/v1/attendance/me', token);
  Future<List<dynamic>> projects(String token) => _getList('/api/v1/projects', token);
  Future<List<dynamic>> payroll(String token) => _getList('/api/v1/payroll', token);
  Future<List<dynamic>> myPayroll(String token) => _getList('/api/v1/payroll/me', token);
  Future<List<dynamic>> jobs() => _getPublicList('/api/v1/jobs');
  Future<List<dynamic>> jobApplications(String token) => _getList('/api/v1/job-applications', token);
  Future<List<dynamic>> myLeave(String token) => _getList('/api/v1/leave/me', token);
  Future<List<dynamic>> leaveRequests(String token) => _getList('/api/v1/leave', token);

  Future<void> requestLeave({required String token, required String leaveType, required String startDate, required String endDate, String? reason}) => _postJson('/api/v1/leave', token, {'leave_type': leaveType, 'start_date': startDate, 'end_date': endDate, 'reason': reason});
  Future<void> reviewLeave(String token, int id, String decision) async => _patch('/api/v1/leave/$id/$decision', token);

  Future<Map<String, dynamic>> createProject(String token, Map<String, dynamic> body) => _postJson('/api/v1/projects', token, body);
  Future<Map<String, dynamic>> createEmployee(String token, Map<String, dynamic> body) => _postJson('/api/v1/employees', token, body);
  Future<Map<String, dynamic>> createPayroll(String token, Map<String, dynamic> body) => _postJson('/api/v1/payroll', token, body);
  Future<Map<String, dynamic>> createJob(String token, Map<String, dynamic> body) => _postJson('/api/v1/jobs', token, body);

  Future<void> checkIn(String token) => _attendanceAction(token, 'check-in');
  Future<void> checkOut(String token) => _attendanceAction(token, 'check-out');

  Future<void> _attendanceAction(String token, String action) async {
    final response = await http.post(Uri.parse('$baseUrl/api/v1/attendance/$action'), headers: _authHeaders(token));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(payload['detail'] ?? 'Attendance action failed');
    }
  }

  Future<List<dynamic>> suppliers(String token) => _getList('/api/v1/commercial/suppliers', token);
  Future<List<dynamic>> materials(String token) => _getList('/api/v1/commercial/materials', token);
  Future<List<dynamic>> lowStockMaterials(String token) => _getList('/api/v1/commercial/materials/low-stock', token);
  Future<List<dynamic>> purchaseOrders(String token) => _getList('/api/v1/commercial/purchase-orders', token);
  Future<List<dynamic>> expenses(String token) => _getList('/api/v1/commercial/expenses', token);
  Future<List<dynamic>> invoices(String token) => _getList('/api/v1/commercial/invoices', token);

  Future<Map<String, dynamic>> createSupplier(String token, Map<String, dynamic> body) => _postJson('/api/v1/commercial/suppliers', token, body);
  Future<Map<String, dynamic>> createMaterial(String token, Map<String, dynamic> body) => _postJson('/api/v1/commercial/materials', token, body);
  Future<Map<String, dynamic>> createPurchaseOrder(String token, Map<String, dynamic> body) => _postJson('/api/v1/commercial/purchase-orders', token, body);
  Future<Map<String, dynamic>> createExpense(String token, Map<String, dynamic> body) => _postJson('/api/v1/commercial/expenses', token, body);
  Future<Map<String, dynamic>> createInvoice(String token, Map<String, dynamic> body) => _postJson('/api/v1/commercial/invoices', token, body);

  Future<List<dynamic>> assets(String token) => _getList('/api/v1/assets', token);
  Future<List<dynamic>> siteReports(String token) => _getList('/api/v1/site-reports', token);
  Future<List<dynamic>> safetyIncidents(String token) => _getList('/api/v1/safety/incidents', token);
  Future<List<dynamic>> notices(String token) => _getList('/api/v1/notices', token);

  Future<Map<String, dynamic>> createAsset(String token, Map<String, dynamic> body) => _postJson('/api/v1/assets', token, body);
  Future<Map<String, dynamic>> createFuelLog(String token, Map<String, dynamic> body) => _postJson('/api/v1/assets/fuel', token, body);
  Future<Map<String, dynamic>> createMaintenance(String token, Map<String, dynamic> body) => _postJson('/api/v1/assets/maintenance', token, body);
  Future<Map<String, dynamic>> createSiteReport(String token, Map<String, dynamic> body) => _postJson('/api/v1/site-reports', token, body);
  Future<Map<String, dynamic>> createSafetyIncident(String token, Map<String, dynamic> body) => _postJson('/api/v1/safety/incidents', token, body);
  Future<Map<String, dynamic>> createNotice(String token, Map<String, dynamic> body) => _postJson('/api/v1/notices', token, body);

  Future<Map<String, dynamic>> dashboardKpis(String token) => _getMap('/api/v1/dashboard/kpis', token);
  Future<Map<String, dynamic>> assetCostSummary(String token) => _getMap('/api/v1/assets/cost-summary', token);
  Future<Map<String, dynamic>> projectProfitability(String token, int projectId) => _getMap('/api/v1/commercial/projects/$projectId/profitability', token);

  Future<List<dynamic>> _getPublicList(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'));
    final payload = jsonDecode(response.body);
    if (response.statusCode != 200) throw Exception(payload is Map<String, dynamic> ? payload['detail'] ?? 'Request failed' : 'Request failed');
    return payload as List<dynamic>;
  }

  Future<List<dynamic>> _getList(String path, String token) async {
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: _authHeaders(token));
    final payload = jsonDecode(response.body);
    if (response.statusCode != 200) throw Exception(payload is Map<String, dynamic> ? payload['detail'] ?? 'Request failed' : 'Request failed');
    return payload as List<dynamic>;
  }

  Future<Map<String, dynamic>> _getMap(String path, String token) async {
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: _authHeaders(token));
    final payload = jsonDecode(response.body);
    if (response.statusCode != 200) throw Exception(payload is Map<String, dynamic> ? payload['detail'] ?? 'Request failed' : 'Request failed');
    return payload as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _postJson(String path, String token, Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl$path'), headers: _authHeaders(token), body: jsonEncode(body));
    final payload = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(payload is Map<String, dynamic> ? payload['detail'] ?? 'Request failed' : 'Request failed');
    return payload as Map<String, dynamic>;
  }

  Future<void> _patch(String path, String token) async {
    final response = await http.patch(Uri.parse('$baseUrl$path'), headers: _authHeaders(token));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final payload = jsonDecode(response.body);
      throw Exception(payload is Map<String, dynamic> ? payload['detail'] ?? 'Request failed' : 'Request failed');
    }
  }
}

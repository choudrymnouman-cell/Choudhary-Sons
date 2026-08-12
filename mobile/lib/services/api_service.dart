import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthSession {
  final String token;
  final int userId;
  final String fullName;
  final String email;
  final String role;

  const AuthSession({
    required this.token,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
  });

  bool get isManagement => const {
        'owner',
        'admin',
        'hr',
        'accountant',
        'project_manager',
        'site_supervisor',
      }.contains(role);
}

class ApiService {
  ApiService({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:8000',
            );

  final String baseUrl;

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<AuthSession> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email.trim(), 'password': password},
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(payload['detail'] ?? 'Login failed');
    }

    final user = payload['user'] as Map<String, dynamic>;
    return AuthSession(
      token: payload['access_token'] as String,
      userId: user['id'] as int,
      fullName: user['full_name'] as String,
      email: user['email'] as String,
      role: user['role'] as String,
    );
  }

  Future<Map<String, dynamic>> myEmployeeProfile(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/employees/me'),
      headers: _authHeaders(token),
    );
    final payload = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(payload['detail'] ?? 'Unable to load profile');
    }
    return payload as Map<String, dynamic>;
  }

  Future<void> checkIn(String token) => _attendanceAction(token, 'check-in');

  Future<void> checkOut(String token) => _attendanceAction(token, 'check-out');

  Future<void> _attendanceAction(String token, String action) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/attendance/$action'),
      headers: _authHeaders(token),
    );
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

  Future<Map<String, dynamic>> projectProfitability(String token, int projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/commercial/projects/$projectId/profitability'),
      headers: _authHeaders(token),
    );
    final payload = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(payload['detail'] ?? 'Unable to load profitability');
    }
    return payload as Map<String, dynamic>;
  }

  Future<List<dynamic>> _getList(String path, String token) async {
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: _authHeaders(token));
    final payload = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(payload is Map<String, dynamic> ? payload['detail'] ?? 'Request failed' : 'Request failed');
    }
    return payload as List<dynamic>;
  }
}

part of 'api_service.dart';

class FastApiService extends ApiService {
  FastApiService() : super._();

  Future<void> registerStaff(String name, String email, String password) async {
    _body(await http.post(_uri('/api/v1/auth/signup'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'full_name':name,'email':email,'password':password})));
  }

  static String? _sessionToken;
  static const baseUrl = String.fromEnvironment('API_BASE_URL');

  @override
  Future<List<dynamic>> boqItems(String token, int projectId) =>
      _getList('/api/v1/commercial/boq/$projectId', token);

  @override
  Future<void> addBoqItem(String token, Map<String, dynamic> item) async {
    await _postJson('/api/v1/commercial/boq', token, item);
  }

  @override
  Future<void> updateBoqProgress(String token, int itemId, num quantity) async {
    await _patchJson('/api/v1/commercial/boq/$itemId/progress', token, {
      'completed_quantity': quantity,
    });
  }

  @override
  Future<List<dynamic>> stockMovements(String token) =>
      _getList('/api/v1/commercial/stock-movements', token);

  @override
  Future<List<dynamic>> deliveries(String token) =>
      _getList('/api/v1/commercial/deliveries', token);

  @override
  Future<List<dynamic>> supplierPayments(String token) =>
      _getList('/api/v1/commercial/supplier-payments', token);

  @override
  Future<List<dynamic>> clients(String token) =>
      _getList('/api/v1/commercial/clients', token);

  @override
  Future<List<dynamic>> receivables(String token) =>
      _getList('/api/v1/commercial/receivables', token);

  @override
  Future<void> recordStockMovement(String token, Map<String, dynamic> data) async {
    await _postJson('/api/v1/commercial/stock-movements', token, data);
  }

  @override
  Future<void> recordDelivery(String token, Map<String, dynamic> data) async {
    await _postJson('/api/v1/commercial/deliveries', token, data);
  }

  @override
  Future<bool> recordSupplierPayment(String token, Map<String, dynamic> data) async {
    final result = await _postJson('/api/v1/commercial/supplier-payments', token, data);
    return result['status'] == 'pending_approval';
  }

  @override
  Future<void> createClient(String token, String name) async {
    await _postJson('/api/v1/commercial/clients', token, {'name': name});
  }

  @override
  Future<void> receiveInvoice(String token, Map<String, dynamic> invoice, double amount) async {
    await _postJson('/api/v1/commercial/invoices/${invoice['id']}/receipts', token, {'amount': amount});
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final token = _sessionToken;
    if (token == null) return null;
    try {
      return _session(token, await _getMap('/api/v1/auth/me', token));
    } on _ApiResponseError catch (error) {
      if (error.status != 401) rethrow;
      _sessionToken = null;
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    _sessionToken = null;
  }

  AuthSession _session(String token, Map<String, dynamic> user) => AuthSession(
    token: token,
    userId: user['id'].toString(),
    fullName: user['full_name'] as String,
    email: user['email'] as String,
    role: user['role'] as String,
  );

  @override
  Future<Uint8List> downloadLocalDocument(String token, int id) async {
    final response = await http.get(_uri('/api/v1/documents/$id/download'),
        headers: _authHeaders(token));
    if (response.statusCode >= 400) _body(response);
    return response.bodyBytes;
  }

  Uri _uri(String path) => Uri.base.resolve('$baseUrl$path');

  Map<String, String> _authHeaders(String token) => {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

  @override
  Future<AuthSession> login(String email, String password) async {
    final response = await http.post(_uri('/api/v1/auth/login'), headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: {'username': email.trim(), 'password': password});
    final payload = _body(response) as Map<String, dynamic>;
    final token = payload['access_token'] as String;
    final session = _session(token, payload['user'] as Map<String, dynamic>);
    _sessionToken = token;
    return session;
  }

  @override
  Future<Map<String, dynamic>> myEmployeeProfile(String token) => _getMap('/api/v1/employees/me', token);
  @override
  Future<List<dynamic>> employees(String token) => _getList('/api/v1/employees', token);
  @override
  Future<List<dynamic>> attendance(String token) => _getList('/api/v1/attendance', token);
  @override
  Future<List<dynamic>> myAttendance(String token) => _getList('/api/v1/attendance/me', token);
  @override
  Future<List<dynamic>> projects(String token) => _getList('/api/v1/projects', token);
  @override
  Future<List<dynamic>> payroll(String token) => _getList('/api/v1/payroll', token);
  @override
  Future<List<dynamic>> myPayroll(String token) => _getList('/api/v1/payroll/me', token);
  @override
  Future<List<dynamic>> jobs() => _getPublicList('/api/v1/jobs');
  @override
  Future<List<dynamic>> jobApplications(String token) => _getList('/api/v1/job-applications', token);
  @override
  Future<List<dynamic>> myLeave(String token) => _getList('/api/v1/leave/me', token);
  @override
  Future<List<dynamic>> leaveRequests(String token) => _getList('/api/v1/leave', token);

  @override
  Future<void> requestLeave({required String token, required String leaveType, required String startDate, required String endDate, String? reason}) => _postJson('/api/v1/leave', token, {'leave_type': leaveType, 'start_date': startDate, 'end_date': endDate, 'reason': reason});
  @override
  Future<void> reviewLeave(String token, int id, String decision) async => _patch('/api/v1/leave/$id/$decision', token);

  @override
  Future<Map<String, dynamic>> createProject(String token, Map<String, dynamic> body) => _postJson('/api/v1/projects', token, body);
  @override
  Future<Map<String, dynamic>> createEmployee(String token, Map<String, dynamic> body) => _postJson('/api/v1/employees', token, body);
  @override
  Future<Map<String, dynamic>> createPayroll(String token, Map<String, dynamic> body) => _postJson('/api/v1/payroll', token, body);
  @override
  Future<Map<String, dynamic>> createJob(String token, Map<String, dynamic> body) => _postJson('/api/v1/jobs', token, body);
  @override
  Future<Map<String, dynamic>> updateProject(String token, int id, Map<String, dynamic> body) => _patchJson('/api/v1/projects/$id', token, body);
  @override
  Future<Map<String, dynamic>> updateEmployee(String token, int id, Map<String, dynamic> body) => _patchJson('/api/v1/employees/$id', token, body);
  @override
  Future<void> deactivateEmployee(String token, int id) => _patch('/api/v1/employees/$id/deactivate', token);

  @override
  Future<void> checkIn(String token) => _attendanceAction(token, 'check-in');
  @override
  Future<void> checkOut(String token) => _attendanceAction(token, 'check-out');

  Future<void> _attendanceAction(String token, String action) async {
    final response = await http.post(_uri('/api/v1/attendance/$action'), headers: _authHeaders(token));
    _body(response);
  }

  @override
  Future<List<dynamic>> suppliers(String token) => _getList('/api/v1/commercial/suppliers', token);
  @override
  Future<List<dynamic>> materials(String token) => _getList('/api/v1/commercial/materials', token);
  @override
  Future<List<dynamic>> lowStockMaterials(String token) => _getList('/api/v1/commercial/materials/low-stock', token);
  @override
  Future<List<dynamic>> purchaseOrders(String token) => _getList('/api/v1/commercial/purchase-orders', token);
  @override
  Future<List<dynamic>> expenses(String token) => _getList('/api/v1/commercial/expenses', token);
  @override
  Future<List<dynamic>> invoices(String token) => _getList('/api/v1/commercial/invoices', token);

  @override
  Future<Map<String, dynamic>> createSupplier(String token, Map<String, dynamic> body) => _postJson('/api/v1/commercial/suppliers', token, body);
  @override
  Future<Map<String, dynamic>> createMaterial(String token, Map<String, dynamic> body) => _postJson('/api/v1/commercial/materials', token, body);
  @override
  Future<Map<String, dynamic>> createPurchaseOrder(String token, Map<String, dynamic> body) => _postJson('/api/v1/commercial/purchase-orders', token, body);
  @override
  Future<Map<String, dynamic>> createExpense(String token, Map<String, dynamic> body) => _postJson('/api/v1/commercial/expenses', token, body);
  @override
  Future<Map<String, dynamic>> createInvoice(String token, Map<String, dynamic> body) => _postJson('/api/v1/commercial/invoices', token, body);

  @override
  Future<List<dynamic>> assets(String token) => _getList('/api/v1/assets', token);
  @override
  Future<List<dynamic>> siteReports(String token) => _getList('/api/v1/site-reports', token);
  @override
  Future<List<dynamic>> safetyIncidents(String token) => _getList('/api/v1/safety/incidents', token);
  @override
  Future<List<dynamic>> notices(String token) => _getList('/api/v1/notices', token);
  @override
  Future<List<dynamic>> documents(String token, {int? projectId, int? employeeId}) {
    final params = <String, String>{};
    if (projectId != null) params['project_id'] = '$projectId';
    if (employeeId != null) params['employee_id'] = '$employeeId';
    final suffix = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    return _getList('/api/v1/documents$suffix', token);
  }

  @override
  Future<Map<String, dynamic>> documentDownloadUrl(String token, int documentId) =>
      _getMap('/api/v1/documents/$documentId/download-url', token);

  @override
  Future<Map<String, dynamic>> uploadDocument({
    required String token,
    required String title,
    required String documentType,
    required String fileName,
    required Uint8List bytes,
    int? projectId,
    int? employeeId,
    String? expiryDate,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/v1/documents'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = title;
    request.fields['document_type'] = documentType;
    if (projectId != null) request.fields['project_id'] = '$projectId';
    if (employeeId != null) request.fields['employee_id'] = '$employeeId';
    if (expiryDate != null && expiryDate.isNotEmpty) request.fields['expiry_date'] = expiryDate;
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _body(response) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> createAsset(String token, Map<String, dynamic> body) => _postJson('/api/v1/assets', token, body);
  @override
  Future<Map<String, dynamic>> createFuelLog(String token, Map<String, dynamic> body) => _postJson('/api/v1/assets/fuel', token, body);
  @override
  Future<Map<String, dynamic>> createMaintenance(String token, Map<String, dynamic> body) => _postJson('/api/v1/assets/maintenance', token, body);
  @override
  Future<Map<String, dynamic>> createSiteReport(String token, Map<String, dynamic> body) => _postJson('/api/v1/site-reports', token, body);
  @override
  Future<Map<String, dynamic>> createSafetyIncident(String token, Map<String, dynamic> body) => _postJson('/api/v1/safety/incidents', token, body);
  @override
  Future<Map<String, dynamic>> createNotice(String token, Map<String, dynamic> body) => _postJson('/api/v1/notices', token, body);

  @override
  Future<Map<String, dynamic>> dashboardKpis(String token) => _getMap('/api/v1/dashboard/kpis', token);
  @override
  Future<Map<String, dynamic>> assetCostSummary(String token) => _getMap('/api/v1/assets/cost-summary', token);
  @override
  Future<Map<String, dynamic>> projectProfitability(String token, int projectId) => _getMap('/api/v1/commercial/projects/$projectId/profitability', token);

  Future<List<dynamic>> _getPublicList(String path) async =>
      _body(await http.get(_uri(path))) as List<dynamic>;

  Future<List<dynamic>> _getList(String path, String token) async =>
      _body(await http.get(_uri(path), headers: _authHeaders(token))) as List<dynamic>;

  Future<Map<String, dynamic>> _getMap(String path, String token) async =>
      _body(await http.get(_uri(path), headers: _authHeaders(token))) as Map<String, dynamic>;

  Future<Map<String, dynamic>> _postJson(String path, String token, Map<String, dynamic> body) async =>
      _body(await http.post(_uri(path), headers: _authHeaders(token), body: jsonEncode(body))) as Map<String, dynamic>;

  Future<Map<String, dynamic>> _patchJson(String path, String token, Map<String, dynamic> body) async =>
      _body(await http.patch(_uri(path), headers: _authHeaders(token), body: jsonEncode(body))) as Map<String, dynamic>;

  Future<void> _patch(String path, String token) async {
    _body(await http.patch(_uri(path), headers: _authHeaders(token)));
  }

  Object? _body(http.Response response) {
    Object? payload;
    try {
      if (response.bodyBytes.isNotEmpty) {
        payload = jsonDecode(utf8.decode(response.bodyBytes));
      }
    } on FormatException {
      throw _ApiResponseError(response.statusCode, 'Unexpected response from the backend.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = payload is Map ? payload['detail'] : null;
      throw _ApiResponseError(response.statusCode, detail?.toString() ?? 'Request failed.');
    }
    return payload;
  }
}

class _ApiResponseError implements Exception {
  const _ApiResponseError(this.status, this.message);
  final int status;
  final String message;

  @override
  String toString() => 'HTTP $status: $message';
}

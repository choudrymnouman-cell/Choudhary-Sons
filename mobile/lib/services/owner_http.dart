part of 'api_service.dart';

class OwnerHttp {
  OwnerHttp(this.token);

  final String token;
  final _api = FastApiService();

  Future<Map<String, dynamic>> overview() =>
      _api._getMap('/api/v1/owner/overview', token);

  Future<List<Map<String, dynamic>>> accounts() async =>
      (await _api._getList('/api/v1/owner/accounts', token))
          .cast<Map<String, dynamic>>();

  Future<List<Map<String, dynamic>>> activity({int? before}) async =>
      (await _api._getList(
        '/api/v1/owner/activity${before == null ? '' : '?before_id=$before'}',
        token,
      )).cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>> thresholds() =>
      _api._getMap('/api/v1/owner/approval-settings', token);

  Future<void> saveThresholds(Map<String, dynamic> body) async {
    const path = '/api/v1/owner/approval-settings';
    _api._body(await http.put(_api._uri(path), headers: _api._authHeaders(token), body: jsonEncode(body)));
  }

  Future<List<Map<String, dynamic>>> approvals() async =>
      (await _api._getList('/api/v1/owner/approvals', token)).cast<Map<String, dynamic>>();

  Future<void> decide(int id, String decision) async {
    await _api._postJson('/api/v1/owner/approvals/$id/$decision', token, {});
  }

  Future<void> saveAccount(Map<String, dynamic> body, {int? id}) async {
    if (id == null) {
      await _api._postJson('/api/v1/owner/accounts', token, body);
      return;
    }
    await _api._patchJson('/api/v1/owner/accounts/$id', token, body);
  }
}

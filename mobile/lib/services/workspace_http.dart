part of 'api_service.dart';

/// Uses the same authenticated FastAPI transport as the rest of the web app.
class WorkspaceHttp {
  WorkspaceHttp(this.token);
  final String token;
  final _api = FastApiService();
  Future<List<Map<String, dynamic>>> list(String path) async =>
      (await _api._getList('/api/v1$path', token)).cast<Map<String, dynamic>>();
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data) =>
      _api._postJson('/api/v1$path', token, data);
  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> data) =>
      _api._patchJson('/api/v1$path', token, data);
}

part of 'api_service.dart';

class RecruitmentHttp {
  final _api = FastApiService();

  String get _token {
    final token = FastApiService._sessionToken;
    if (token == null) throw StateError('Please sign in again.');
    return token;
  }

  String _path(String resource) => '/api/v1/recruitment/$resource';

  Future<Object?> get(String resource) async => _api._body(
    await http.get(_api._uri(_path(resource)), headers: _api._authHeaders(_token)),
  );

  Future<List<Map<String, dynamic>>> rows(String resource) async =>
      (await get(resource) as List).cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>?> row(String resource) async =>
      await get(resource) as Map<String, dynamic>?;

  Future<Map<String, dynamic>> post(String resource, Map<String, dynamic> body) =>
      _api._postJson(_path(resource), _token, body);

  Future<Map<String, dynamic>> put(String resource, Map<String, dynamic> body) async =>
      _api._body(await http.put(_api._uri(_path(resource)),
        headers: _api._authHeaders(_token), body: jsonEncode(body))) as Map<String, dynamic>;

  Future<void> patch(String resource, [Map<String, dynamic>? body]) async {
    _api._body(await http.patch(_api._uri(_path(resource)),
      headers: _api._authHeaders(_token), body: body == null ? null : jsonEncode(body)));
  }

  Future<void> closeJob(int jobId) => _api._patch('/api/v1/jobs/$jobId/close', _token);

  Future<void> delete(String resource) async {
    _api._body(await http.delete(_api._uri(_path(resource)), headers: _api._authHeaders(_token)));
  }

  Future<void> signup(Map<String, dynamic> profile) async {
    _api._body(await http.post(_api._uri(_path('signup')),
      headers: {'Content-Type': 'application/json'}, body: jsonEncode(profile)));
  }

  Future<String> upload(String kind, String fileName, Uint8List bytes) async {
    final request = http.MultipartRequest('POST', _api._uri(_path('files/$kind')))
      ..headers['Authorization'] = 'Bearer $_token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final response = await http.Response.fromStream(await request.send());
    return (_api._body(response) as Map<String, dynamic>)['id'] as String;
  }

  Future<({String name, Uint8List bytes})> download(String fileId) async {
    final response = await http.get(_api._uri(_path('files/${Uri.encodeComponent(fileId)}')),
      headers: _api._authHeaders(_token));
    if (response.statusCode >= 400) _api._body(response);
    final disposition = response.headers['content-disposition'] ?? '';
    final utf8 = RegExp(r"filename\*=utf-8''([^;]+)", caseSensitive: false).firstMatch(disposition);
    final plain = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
    final name = utf8 == null ? plain?.group(1) ?? 'Applicant document' : Uri.decodeComponent(utf8.group(1)!);
    return (name: name, bytes: response.bodyBytes);
  }
}

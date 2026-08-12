import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.session});
  final AuthSession session;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _api = ApiService();
  late Future<List<dynamic>> _documents;

  @override
  void initState() {
    super.initState();
    _documents = _api.documents(widget.session.token);
  }

  void _refresh() => setState(() => _documents = _api.documents(widget.session.token));

  Future<void> _upload() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DocumentUploadScreen(session: widget.session)),
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _documents,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString().replaceFirst('Exception: ', '')));
          }
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) return const Center(child: Text('No documents uploaded yet.'));
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = Map<String, dynamic>.from(rows[index] as Map);
                final target = item['project_id'] != null
                    ? 'Project #${item['project_id']}'
                    : 'Employee #${item['employee_id']}';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
                    title: Text((item['title'] ?? 'Document').toString()),
                    subtitle: Text('${item['document_type'] ?? 'file'} • $target${item['expiry_date'] != null ? ' • Expires ${item['expiry_date']}' : ''}'),
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

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key, required this.session});
  final AuthSession session;

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final _api = ApiService();
  final _title = TextEditingController();
  final _type = TextEditingController(text: 'general');
  final _expiry = TextEditingController();
  List<dynamic> _projects = [];
  List<dynamic> _employees = [];
  int? _projectId;
  int? _employeeId;
  PlatformFile? _file;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  @override
  void dispose() {
    _title.dispose();
    _type.dispose();
    _expiry.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final results = await Future.wait([
        _api.projects(widget.session.token),
        _api.employees(widget.session.token),
      ]);
      if (!mounted) return;
      setState(() {
        _projects = results[0];
        _employees = results[1];
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'doc', 'docx', 'xls', 'xlsx'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _file = result.files.single);
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _type.text.trim().isEmpty || _file?.bytes == null) {
      setState(() => _error = 'Enter a title, document type, and choose a file.');
      return;
    }
    if (_projectId == null && _employeeId == null) {
      setState(() => _error = 'Select a project or employee.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.uploadDocument(
        token: widget.session.token,
        title: _title.text.trim(),
        documentType: _type.text.trim(),
        fileName: _file!.name,
        bytes: _file!.bytes!,
        projectId: _projectId,
        employeeId: _employeeId,
        expiryDate: _expiry.text.trim().isEmpty ? null : _expiry.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Document')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _type, decoration: const InputDecoration(labelText: 'Document type', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _projectId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Project (optional)', border: OutlineInputBorder()),
            items: _projects.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              return DropdownMenuItem<int>(value: item['id'] as int, child: Text('${item['code'] ?? ''} — ${item['name'] ?? 'Project'}', overflow: TextOverflow.ellipsis));
            }).toList(),
            onChanged: (value) => setState(() => _projectId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _employeeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Employee (optional)', border: OutlineInputBorder()),
            items: _employees.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              return DropdownMenuItem<int>(value: item['id'] as int, child: Text('${item['employee_code'] ?? ''} — ${item['full_name'] ?? 'Employee'}', overflow: TextOverflow.ellipsis));
            }).toList(),
            onChanged: (value) => setState(() => _employeeId = value),
          ),
          const SizedBox(height: 12),
          TextField(controller: _expiry, decoration: const InputDecoration(labelText: 'Expiry date (YYYY-MM-DD, optional)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.attach_file),
            label: Text(_file == null ? 'Choose file' : _file!.name),
          ),
          if (_file != null) ...[
            const SizedBox(height: 6),
            Text('${(_file!.size / 1024).toStringAsFixed(1)} KB', style: Theme.of(context).textTheme.bodySmall),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(_saving ? 'Uploading...' : 'Upload Document'),
          ),
        ],
      ),
    );
  }
}

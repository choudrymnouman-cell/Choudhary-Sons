import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/applicant_portal_service.dart';

class ApplicantProfileScreen extends StatefulWidget {
  const ApplicantProfileScreen({super.key, required this.service, required this.initial});
  final ApplicantPortalService service;
  final Map<String, dynamic>? initial;

  @override
  State<ApplicantProfileScreen> createState() => _ApplicantProfileScreenState();
}

class _ApplicantProfileScreenState extends State<ApplicantProfileScreen> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> c;
  bool saving = false;
  String? photoPath, cnicFrontPath, cnicBackPath, experiencePath;

  @override
  void initState() {
    super.initState();
    final p = widget.initial ?? {};
    final keys = ['full_name','father_name','cnic','cnic_name','whatsapp_number','phone','education','experience_years','experience_details','skills','bank_account_title','bank_account_number','bank_name','address','city'];
    c = {for (final k in keys) k: TextEditingController(text: p[k]?.toString() ?? '')};
    photoPath = p['profile_photo_path']?.toString();
    cnicFrontPath = p['cnic_front_path']?.toString();
    cnicBackPath = p['cnic_back_path']?.toString();
    experiencePath = p['experience_document_path']?.toString();
  }

  @override
  void dispose() { for (final x in c.values) { x.dispose(); } super.dispose(); }

  Future<String?> pickAndUpload(String kind) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg','jpeg','png','pdf'], withData: true);
    if (result == null || result.files.single.bytes == null) return null;
    final file = result.files.single;
    return widget.service.uploadApplicantFile(kind: kind, fileName: file.name, bytes: Uint8List.fromList(file.bytes!));
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    if (c['full_name']!.text.trim().toLowerCase() != c['cnic_name']!.text.trim().toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile name must exactly match the name on CNIC.')));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.service.upsertProfile({
        ...{for (final e in c.entries) e.key: e.value.text.trim()},
        'experience_years': double.tryParse(c['experience_years']!.text.trim()) ?? 0,
        'profile_photo_path': photoPath,
        'cnic_front_path': cnicFrontPath,
        'cnic_back_path': cnicBackPath,
        'experience_document_path': experiencePath,
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved successfully.'))); Navigator.pop(context); }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('Personal & Identity Information', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('The full name entered here must be the same as the name on your CNIC.'),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _Upload(label: 'Profile Photo', ready: photoPath != null, onTap: () async { photoPath = await pickAndUpload('profile_photo') ?? photoPath; setState(() {}); }),
              _Upload(label: 'CNIC Front', ready: cnicFrontPath != null, onTap: () async { cnicFrontPath = await pickAndUpload('cnic_front') ?? cnicFrontPath; setState(() {}); }),
              _Upload(label: 'CNIC Back', ready: cnicBackPath != null, onTap: () async { cnicBackPath = await pickAndUpload('cnic_back') ?? cnicBackPath; setState(() {}); }),
              _Upload(label: 'Experience Docs', ready: experiencePath != null, onTap: () async { experiencePath = await pickAndUpload('experience') ?? experiencePath; setState(() {}); }),
            ]),
            const SizedBox(height: 18),
            ...[
              ('full_name','Full Name'),('father_name','Father Name'),('cnic','CNIC Number'),('cnic_name','Name on CNIC'),('whatsapp_number','WhatsApp Number'),('phone','Alternate Phone'),('education','Education'),('experience_years','Experience (Years)'),('experience_details','Experience Details'),('skills','Skills'),('bank_account_title','Account Title'),('bank_account_number','Account Number / IBAN'),('bank_name','Bank Name'),('address','Address'),('city','City')
            ].map((x) {
              final required = const {'full_name','father_name','cnic','cnic_name','whatsapp_number','education'}.contains(x.$1);
              final multiline = const {'experience_details','skills','address'}.contains(x.$1);
              return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: c[x.$1], maxLines: multiline ? 3 : 1, decoration: InputDecoration(labelText: x.$2), validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null));
            }),
            const SizedBox(height: 4),
            FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save_outlined), label: Text(saving ? 'Saving...' : 'Save Profile')),
          ],
        ),
      ),
    );
  }
}

class _Upload extends StatelessWidget {
  const _Upload({required this.label, required this.ready, required this.onTap});
  final String label; final bool ready; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(width: 165, child: OutlinedButton.icon(onPressed: onTap, icon: Icon(ready ? Icons.check_circle : Icons.upload_file), label: Text(label)));
}

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ApplicantPortalService {
  SupabaseClient get _db => Supabase.instance.client;

  User get _user {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Please sign in again.');
    return user;
  }

  Future<void> signUp({required String email, required String password, required String fullName, String? phone}) async {
    final response = await _db.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim(), 'phone': phone?.trim()},
    );
    if (response.user == null) throw Exception('Unable to create account.');
    if (response.session != null) {
      await ensureApplicantRole();
      await ensureApplicantProfile(fullName: fullName.trim(), phone: phone?.trim());
    }
  }

  Future<void> ensureApplicantRole() async {
    await _db.rpc('register_as_applicant', params: {
      'p_full_name': (_user.userMetadata?['full_name'] ?? '').toString(),
      'p_phone': _user.userMetadata?['phone']?.toString(),
    });
    await ensureApplicantProfile(
      fullName: (_user.userMetadata?['full_name'] ?? _user.email ?? 'Applicant').toString(),
      phone: _user.userMetadata?['phone']?.toString(),
    );
  }

  Future<Map<String, dynamic>> ensureApplicantProfile({required String fullName, String? phone}) async {
    final existing = await myProfile();
    if (existing != null) return existing;
    final body = <String, dynamic>{
      'user_id': _user.id,
      'full_name': fullName.trim().isEmpty ? (_user.email ?? 'Applicant') : fullName.trim(),
      'phone': _clean(phone),
      'whatsapp_number': _clean(phone),
      'is_profile_complete': false,
    };
    body.removeWhere((key, value) => value == null);
    return Map<String, dynamic>.from(await _db.from('applicant_profiles').insert(body).select().single());
  }

  Future<Map<String, dynamic>?> myProfile() async {
    final rows = await _db.from('applicant_profiles').select().eq('user_id', _user.id).limit(1);
    if ((rows as List).isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<Map<String, dynamic>> upsertProfile(Map<String, dynamic> values) async {
    final body = <String, dynamic>{'user_id': _user.id, ...values};
    body.removeWhere((key, value) => value == null);
    body['is_profile_complete'] = _isComplete(body);
    body['updated_at'] = DateTime.now().toUtc().toIso8601String();

    final saved = Map<String, dynamic>.from(
      await _db.from('applicant_profiles').upsert(body).select().single(),
    );

    await _db.rpc('register_as_applicant', params: {
      'p_full_name': saved['full_name']?.toString() ?? '',
      'p_phone': saved['phone']?.toString() ?? saved['whatsapp_number']?.toString(),
    });
    return saved;
  }

  bool _isComplete(Map<String, dynamic> p) {
    bool present(String key) => _clean(p[key]?.toString()) != null;
    final fullName = _clean(p['full_name']?.toString())?.toLowerCase();
    final cnicName = _clean(p['cnic_name']?.toString())?.toLowerCase();
    return present('full_name') && present('father_name') && present('cnic') && present('cnic_name') &&
        fullName == cnicName && present('whatsapp_number') && present('education') &&
        present('profile_photo_path') && present('cnic_front_path') && present('cnic_back_path');
  }

  String? _clean(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  Future<String> uploadApplicantFile({required String kind, required String fileName, required Uint8List bytes}) async {
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '${_user.id}/$kind/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await _db.storage.from('applicant-documents').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
    return path;
  }

  Future<String> signedApplicantFileUrl(String path) => _db.storage.from('applicant-documents').createSignedUrl(path, 600);

  Future<List<dynamic>> openJobs() async => List<dynamic>.from(
    await _db.from('job_vacancies').select().eq('is_open', true).order('created_at', ascending: false),
  );

  Future<List<dynamic>> myApplications() async => List<dynamic>.from(
    await _db.from('job_applications').select('*, job_vacancies(title,department,location,employment_type)')
      .eq('applicant_user_id', _user.id).order('created_at', ascending: false),
  );

  Future<void> applyForJob({required int vacancyId, String? coverLetter, double? expectedSalary}) async {
    final profile = await myProfile();
    if (profile == null || profile['is_profile_complete'] != true) {
      throw Exception('Complete your profile, profile photo and CNIC images before applying.');
    }
    final existing = await _db.from('job_applications').select('id')
      .eq('vacancy_id', vacancyId).eq('applicant_user_id', _user.id).limit(1);
    if ((existing as List).isNotEmpty) throw Exception('You already applied for this job.');
    await _db.from('job_applications').insert({
      'vacancy_id': vacancyId,
      'applicant_user_id': _user.id,
      'applicant_profile_id': _user.id,
      'applicant_name': profile['full_name'],
      'email': _user.email ?? '',
      'phone': profile['whatsapp_number'] ?? profile['phone'],
      'cnic': profile['cnic'],
      'experience_years': profile['experience_years'] ?? 0,
      'cover_note': coverLetter,
      'cover_letter': coverLetter,
      'expected_salary': expectedSalary,
      'status': 'applied',
    });
  }

  Future<List<dynamic>> conversations() async => List<dynamic>.from(
    await _db.from('hr_conversations').select().order('updated_at', ascending: false),
  );

  Future<Map<String, dynamic>> openConversation({int? applicationId, String subject = 'General HR Support'}) async {
    dynamic query = _db.from('hr_conversations').select().eq('applicant_user_id', _user.id);
    if (applicationId == null) {
      query = query.isFilter('job_application_id', null);
    } else {
      query = query.eq('job_application_id', applicationId);
    }
    final existing = await query.limit(1);
    if ((existing as List).isNotEmpty) return Map<String, dynamic>.from(existing.first as Map);
    final payload = <String, dynamic>{
      'applicant_user_id': _user.id,
      'subject': subject,
      if (applicationId != null) 'job_application_id': applicationId,
    };
    return Map<String, dynamic>.from(await _db.from('hr_conversations').insert(payload).select().single());
  }

  Future<List<dynamic>> messages(int conversationId) async => List<dynamic>.from(
    await _db.from('hr_messages').select().eq('conversation_id', conversationId).order('created_at'),
  );

  Future<void> sendMessage(int conversationId, String message) async {
    final text = message.trim();
    if (text.isEmpty) return;
    await _db.from('hr_messages').insert({
      'conversation_id': conversationId,
      'sender_user_id': _user.id,
      'message': text,
    });
    await _db.from('hr_conversations').update({'updated_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', conversationId);
  }

  Future<List<dynamic>> myInterviews() async => List<dynamic>.from(
    await _db.from('interviews').select('*, job_applications(applicant_name, job_vacancies(title))')
      .eq('applicant_user_id', _user.id).order('scheduled_at'),
  );
}

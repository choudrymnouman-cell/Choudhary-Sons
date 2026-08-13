import 'package:supabase_flutter/supabase_flutter.dart';

class RecruitmentPipelineService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Map<String, dynamic>>> applications() async {
    final rows = await _db.from('job_applications').select('*, job_vacancies(title,department,location,employment_type)').order('created_at', ascending: false);
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>?> applicantProfile(String userId) async {
    final rows = await _db.from('applicant_profiles').select().eq('user_id', userId).limit(1);
    if ((rows as List).isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<List<Map<String, dynamic>>> notes(int applicationId) async {
    final rows = await _db.from('hr_application_notes').select().eq('application_id', applicationId).order('created_at', ascending: false);
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> addNote(int applicationId, String note) async {
    final text = note.trim();
    if (text.isEmpty) return;
    await _db.from('hr_application_notes').insert({'application_id': applicationId, 'note': text, 'created_by': _db.auth.currentUser!.id});
  }

  Future<void> setStatus(int applicationId, String status) async {
    await _db.from('job_applications').update({'status': status}).eq('id', applicationId);
  }

  Future<void> scheduleInterview({required int applicationId, required String applicantUserId, required DateTime scheduledAt, int durationMinutes = 30, String interviewType = 'video', String? meetingUrl, String? roomCode, String? notes}) async {
    await _db.from('interviews').insert({
      'application_id': applicationId,
      'applicant_user_id': applicantUserId,
      'hr_user_id': _db.auth.currentUser!.id,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'interview_type': interviewType,
      'meeting_url': meetingUrl?.trim().isEmpty == true ? null : meetingUrl?.trim(),
      'room_code': roomCode?.trim().isEmpty == true ? null : roomCode?.trim(),
      'status': 'scheduled',
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
    });
    await setStatus(applicationId, 'interview');
  }

  Future<int> hire({required int applicationId, required String employeeCode, required String designation, String? department, double basicSalary = 0, DateTime? joiningDate}) async {
    final id = await _db.rpc('hire_applicant', params: {
      'p_application_id': applicationId,
      'p_employee_code': employeeCode.trim(),
      'p_designation': designation.trim(),
      'p_department': department?.trim(),
      'p_basic_salary': basicSalary,
      'p_joining_date': (joiningDate ?? DateTime.now()).toIso8601String().substring(0, 10),
    });
    return id as int;
  }

  Future<String> signedDocumentUrl(String path) => _db.storage.from('applicant-documents').createSignedUrl(path, 600);
}

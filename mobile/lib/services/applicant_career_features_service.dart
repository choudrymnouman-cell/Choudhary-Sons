import 'package:supabase_flutter/supabase_flutter.dart';

class ApplicantCareerFeaturesService {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> notifications() async {
    final rows = await _db.from('applicant_notifications').select().eq('user_id', _uid).order('created_at', ascending: false);
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> markNotificationRead(int id) async {
    await _db.from('applicant_notifications').update({'is_read': true}).eq('id', id).eq('user_id', _uid);
  }

  Future<Map<String, dynamic>?> preferences() async {
    final rows = await _db.from('applicant_job_preferences').select().eq('user_id', _uid).limit(1);
    if ((rows as List).isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<void> savePreferences({String? department, String? location, String? employmentType, double? minSalary, required bool receiveJobAlerts}) async {
    await _db.from('applicant_job_preferences').upsert({
      'user_id': _uid,
      'preferred_department': department?.trim().isEmpty == true ? null : department?.trim(),
      'preferred_location': location?.trim().isEmpty == true ? null : location?.trim(),
      'preferred_employment_type': employmentType?.trim().isEmpty == true ? null : employmentType?.trim(),
      'min_expected_salary': minSalary,
      'receive_job_alerts': receiveJobAlerts,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> applicationHistory(int applicationId) async {
    final rows = await _db.from('application_status_history').select().eq('application_id', applicationId).order('created_at');
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

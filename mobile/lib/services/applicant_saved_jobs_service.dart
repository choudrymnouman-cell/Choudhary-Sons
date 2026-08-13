import 'package:supabase_flutter/supabase_flutter.dart';

class ApplicantSavedJobsService {
  SupabaseClient get _db => Supabase.instance.client;

  String get _userId {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Please sign in again.');
    return user.id;
  }

  Future<List<dynamic>> savedJobs() async => List<dynamic>.from(
        await _db
            .from('saved_jobs')
            .select('*, job_vacancies(*)')
            .eq('applicant_user_id', _userId)
            .order('created_at', ascending: false),
      );

  Future<void> saveJob(int vacancyId) async {
    await _db.from('saved_jobs').upsert({
      'applicant_user_id': _userId,
      'vacancy_id': vacancyId,
    });
  }

  Future<void> unsaveJob(int vacancyId) async {
    await _db
        .from('saved_jobs')
        .delete()
        .eq('applicant_user_id', _userId)
        .eq('vacancy_id', vacancyId);
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_service.dart';

class ApplicantSavedJobsService {
  final _http = RecruitmentHttp();
  SupabaseClient get _db => Supabase.instance.client;

  String get _userId {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Please sign in again.');
    return user.id;
  }

  Future<List<dynamic>> savedJobs() async => selfHostedWeb ? _http.rows('saved-jobs') : List<dynamic>.from(
        await _db
            .from('saved_jobs')
            .select('*, job_vacancies(*)')
            .eq('applicant_user_id', _userId)
            .order('created_at', ascending: false),
      );

  Future<void> saveJob(int vacancyId) async {
    if (selfHostedWeb) {
      await _http.put('saved-jobs/$vacancyId', {});
      return;
    }
    await _db.from('saved_jobs').upsert({
      'applicant_user_id': _userId,
      'vacancy_id': vacancyId,
    });
  }

  Future<void> unsaveJob(int vacancyId) async {
    if (selfHostedWeb) return _http.delete('saved-jobs/$vacancyId');
    await _db
        .from('saved_jobs')
        .delete()
        .eq('applicant_user_id', _userId)
        .eq('vacancy_id', vacancyId);
  }
}

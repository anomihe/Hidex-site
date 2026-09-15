import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_init.dart';
import '../models/reading_plan.dart';

class ReadingPlansService {
  ReadingPlansService(this._client);

  final SupabaseClient _client;

  Future<List<ReadingPlan>> fetchPlans() async {
    final rows = await _client.from('reading_plans').select().order('created_at', ascending: false);
    return (rows as List).map((r) => ReadingPlan.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<List<ReadingPlanDay>> fetchDays(String planId) async {
    final rows = await _client
        .from('reading_plan_days')
        .select()
        .eq('plan_id', planId)
        .order('day_number');
    return (rows as List).map((r) => ReadingPlanDay.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<ReadingPlanEnrollment?> fetchMyEnrollment(String planId) async {
    final row = await _client
        .from('reading_plan_enrollments')
        .select()
        .eq('plan_id', planId)
        .eq('user_id', _client.auth.currentUser!.id)
        .maybeSingle();
    return row == null ? null : ReadingPlanEnrollment.fromJson(row);
  }

  Future<ReadingPlanEnrollment> enroll(String planId) async {
    final row = await _client
        .from('reading_plan_enrollments')
        .upsert(
          {'plan_id': planId, 'user_id': _client.auth.currentUser!.id},
          onConflict: 'plan_id,user_id',
        )
        .select()
        .single();
    return ReadingPlanEnrollment.fromJson(row);
  }

  Future<Set<int>> fetchCompletedDays(String enrollmentId) async {
    final rows = await _client
        .from('reading_plan_completions')
        .select('day_number')
        .eq('enrollment_id', enrollmentId);
    return (rows as List).map((r) => r['day_number'] as int).toSet();
  }

  Future<UserStreak> completeDay({required String enrollmentId, required int dayNumber}) async {
    final row = await _client.rpc('complete_reading_day', params: {
      'p_enrollment_id': enrollmentId,
      'p_day_number': dayNumber,
    });
    return UserStreak.fromJson(row as Map<String, dynamic>);
  }

  Future<UserStreak> fetchStreak() async {
    final row = await _client
        .from('user_streaks')
        .select()
        .eq('user_id', _client.auth.currentUser!.id)
        .maybeSingle();
    return row == null ? UserStreak.zero : UserStreak.fromJson(row);
  }
}

final readingPlansService = ReadingPlansService(supabase);

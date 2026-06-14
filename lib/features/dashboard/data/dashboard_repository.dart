import '../../../core/services/supabase_service.dart';

class DashboardRepository {
  Future<Map<String, dynamic>> stats() async {
    final data = await sb.rpc('dashboard_stats');
    return Map<String, dynamic>.from(data as Map);
  }
}

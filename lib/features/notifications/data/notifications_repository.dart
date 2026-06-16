import '../../../core/services/supabase_service.dart';

class NotificationsRepository {
  Future<int> unreadCount() async {
    final userId = sb.auth.currentUser?.id;
    if (userId == null) return 0;
    final data = await sb
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false) as List;
    return data.length;
  }

  Future<List<Map<String, dynamic>>> listNotifications({int limit = 60}) async {
    final userId = sb.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await sb
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit) as List;
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> markAsRead(String id) async {
    await sb.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllAsRead() async {
    final userId = sb.auth.currentUser?.id;
    if (userId == null) return;
    await sb
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }
}

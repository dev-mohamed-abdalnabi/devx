import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/notification_service.dart';
import 'supabase_config.dart';

/// يستمع لإشعارات المستخدم الجديدة من Supabase ويعرضها كإشعار أندرويد.
/// يعمل ما دامت عملية التطبيق حيّة (حتى في الخلفية). للإشعار والتطبيق مغلق تمامًا
/// يلزم FCM (المرحلة 3).
class CommunityRealtime {
  static RealtimeChannel? _channel;
  static StreamSubscription<AuthState>? _auth;

  static void start() {
    _auth ??= supabase.auth.onAuthStateChange.listen((_) => _resubscribe());
    _resubscribe();
  }

  static Future<void> _resubscribe() async {
    final old = _channel;
    _channel = null;
    if (old != null) await supabase.removeChannel(old);
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    _channel = supabase
        .channel('community-notifs-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (payload) => _show(payload.newRecord),
        )
        .subscribe();
  }

  static Future<void> _show(Map<String, dynamic> n) async {
    String who = 'عضو';
    try {
      if (n['actor_id'] != null) {
        final p = await supabase
            .from('profiles')
            .select('full_name, username')
            .eq('id', n['actor_id'])
            .single();
        final full = (p['full_name'] ?? '').toString().trim();
        who = full.isNotEmpty ? full : '@${p['username']}';
      }
    } catch (_) {}
    final text = switch (n['type']) {
      'like' => 'أعجب بمنشورك',
      'comment' => 'علّق على منشورك',
      'reply' => 'ردّ على تعليقك',
      'comment_like' => 'أعجب بتعليقك',
      'new_post' => 'نشر منشورًا جديدًا',
      'share' => 'شارك منشورك',
      'group_join' => 'طلب الانضمام إلى جروبك',
      'group_approved' => 'تمت الموافقة على انضمامك للجروب',
      _ => 'لديك تحديث جديد',
    };
    await NotificationService.showCommunity(
        (n['id'].toString().hashCode & 0x3fffffff), 'المنتدى', '$who $text');
  }
}

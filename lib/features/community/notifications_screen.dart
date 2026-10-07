import 'package:flutter/material.dart';

import '../../services/supabase_config.dart';
import '../../widgets/app_ui.dart';
import 'community_utils.dart';

class CommunityNotificationsScreen extends StatefulWidget {
  const CommunityNotificationsScreen({super.key});
  @override
  State<CommunityNotificationsScreen> createState() =>
      _CommunityNotificationsScreenState();
}

class _CommunityNotificationsScreenState
    extends State<CommunityNotificationsScreen> {
  bool _loading = true;
  bool _failed = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await supabase
          .from('notifications')
          .select(
              '*, profiles!notifications_actor_id_fkey(full_name, username)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      final items = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
          _failed = false;
        });
      }
      // نعلّمها كمقروءة بعد العرض، فتبقى غير المقروءة مميّزة في هذه الزيارة.
      if (items.any((n) => n['is_read'] != true)) {
        await supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId)
            .eq('is_read', false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> n) async {
    final index = _items.indexOf(n);
    setState(() => _items.remove(n));
    try {
      await supabase.from('notifications').delete().eq('id', n['id']);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items.insert(index.clamp(0, _items.length), n));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذر حذف الإشعار.')));
    }
  }

  (IconData, String) _describe(String type) {
    switch (type) {
      case 'like':
        return (Icons.favorite_rounded, 'أعجب بمنشورك');
      case 'comment':
        return (Icons.mode_comment_rounded, 'علّق على منشورك');
      case 'reply':
        return (Icons.reply_rounded, 'ردّ على تعليقك');
      case 'comment_like':
        return (Icons.favorite_rounded, 'أعجب بتعليقك');
      case 'new_post':
        return (Icons.notifications_active_rounded, 'نشر منشورًا جديدًا');
      case 'share':
        return (Icons.repeat_rounded, 'شارك منشورك');
      case 'follow':
        return (Icons.person_add_alt_1_rounded, 'بدأ متابعتك');
      case 'group_join':
        return (Icons.groups_rounded, 'طلب الانضمام إلى جروبك أو انضم إليه');
      case 'group_approved':
        return (
          Icons.check_circle_rounded,
          'تمت الموافقة على انضمامك إلى الجروب'
        );
      case 'mention':
        return (Icons.alternate_email_rounded, 'ذكرك في منشور');
      case 'report_update':
        return (Icons.flag_rounded, 'تم تحديث حالة بلاغك');
      default:
        return (Icons.notifications_active_outlined, 'لديك تحديث جديد');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_failed) {
      body = ListView(children: const [
        AppEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'تعذر تحميل الإشعارات',
            message: 'اسحب للأسفل لإعادة المحاولة.')
      ]);
    } else if (_items.isEmpty) {
      body = ListView(children: const [
        AppEmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'لا توجد إشعارات',
            message: 'ستظهر هنا التفاعلات الجديدة على منشوراتك.')
      ]);
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final n = _items[i];
          final p = (n['profiles'] as Map?)?.cast<String, dynamic>();
          final (icon, text) = _describe(n['type']?.toString() ?? '');
          final hasActor = p != null && n['actor_id'] != null;
          final unread = n['is_read'] != true;
          return Dismissible(
            key: ValueKey(n['id']),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => _delete(n),
            background: Container(
                decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(20)),
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Icon(Icons.delete_outline_rounded,
                    color: scheme.onErrorContainer)),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              color: unread
                  ? scheme.primaryContainer.withValues(alpha: .45)
                  : null,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AppIconBadge(icon: icon, size: 44),
                title: Text(hasActor ? '${displayName(p)} $text' : text,
                    style: TextStyle(
                        fontWeight:
                            unread ? FontWeight.w800 : FontWeight.w600)),
                subtitle: Text(timeAgo(n['created_at']?.toString())),
                trailing: unread
                    ? Icon(Icons.circle, size: 10, color: scheme.primary)
                    : null,
              ),
            ),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}

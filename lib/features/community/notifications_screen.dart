import 'package:flutter/material.dart';
import '../../services/supabase_config.dart';
import '../../widgets/app_ui.dart';

class CommunityNotificationsScreen extends StatefulWidget {
  const CommunityNotificationsScreen({super.key});
  @override State<CommunityNotificationsScreen> createState() => _CommunityNotificationsScreenState();
}
class _CommunityNotificationsScreenState extends State<CommunityNotificationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final data = await supabase.from('notifications').select('*, profiles!notifications_actor_id_fkey(full_name, username)').eq('user_id', supabase.auth.currentUser!.id).order('created_at', ascending: false).limit(50); await supabase.from('notifications').update({'is_read': true}).eq('user_id', supabase.auth.currentUser!.id); if (mounted) setState(() { _items = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(); _loading = false; }); } catch (_) { if (mounted) setState(() => _loading = false); } }
  String _label(String type) { switch (type) { case 'like': return 'أعجب بمنشورك'; case 'comment': return 'علّق على منشورك'; case 'share': return 'شارك منشورك'; case 'follow': return 'بدأ متابعتك'; case 'group_join': return 'انضم إلى جروبك'; default: return 'لديك تحديث جديد'; } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('الإشعارات')), body: _loading ? const Center(child: CircularProgressIndicator()) : _items.isEmpty ? const AppEmptyState(icon: Icons.notifications_none_rounded, title: 'لا توجد إشعارات', message: 'ستظهر هنا التفاعلات الجديدة على منشوراتك.') : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, i) { final n = _items[i]; final p = (n['profiles'] as Map?)?.cast<String, dynamic>() ?? {}; final actor = p['full_name']?.toString().isNotEmpty == true ? p['full_name'].toString() : '@${p['username'] ?? 'عضو'}'; return AppCard(padding: const EdgeInsets.all(14), child: ListTile(contentPadding: EdgeInsets.zero, leading: const AppIconBadge(icon: Icons.notifications_active_outlined, size: 44), title: Text('$actor ${_label(n['type']?.toString() ?? '')}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(n['created_at']?.toString().replaceFirst('T', ' ').split('.').first ?? ''),)); }));
}

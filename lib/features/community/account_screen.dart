import 'package:flutter/material.dart';
import '../../services/supabase_config.dart';

class CommunityAccountScreen extends StatefulWidget {
  const CommunityAccountScreen({super.key});
  @override State<CommunityAccountScreen> createState() => _CommunityAccountScreenState();
}

class _CommunityAccountScreenState extends State<CommunityAccountScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  int _posts = 0;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _name.dispose(); _username.dispose(); _bio.dispose(); super.dispose(); }
  Future<void> _load() async { final id = supabase.auth.currentUser?.id; if (id == null) return; try { final profile = await supabase.from('profiles').select().eq('id', id).single(); final posts = await supabase.from('posts').select('id').eq('author_id', id); _name.text = profile['full_name']?.toString() ?? ''; _username.text = profile['username']?.toString() ?? ''; _bio.text = profile['bio']?.toString() ?? ''; if (mounted) setState(() { _posts = (posts as List).length; _loading = false; }); } catch (_) { if (mounted) setState(() => _loading = false); } }
  Future<void> _save() async { if (_username.text.trim().length < 3) { _message('اسم المستخدم 3 أحرف على الأقل.'); return; } setState(() => _saving = true); try { await supabase.from('profiles').update({'full_name': _name.text.trim(), 'username': _username.text.trim().toLowerCase(), 'bio': _bio.text.trim(), 'updated_at': DateTime.now().toIso8601String()}).eq('id', supabase.auth.currentUser!.id); if (mounted) _message('تم حفظ بيانات حسابك.'); } catch (_) { if (mounted) _message('اسم المستخدم مستخدم أو تعذر الحفظ.'); } finally { if (mounted) setState(() => _saving = false); } }
  Future<void> _signOut() async { await supabase.auth.signOut(); if (mounted) Navigator.pop(context, true); }
  void _message(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  @override Widget build(BuildContext context) { final scheme = Theme.of(context).colorScheme; return Scaffold(appBar: AppBar(title: const Text('حسابي')), body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(20), children: [Center(child: CircleAvatar(radius: 42, backgroundColor: scheme.primaryContainer, child: Icon(Icons.person_rounded, size: 44, color: scheme.primary))), const SizedBox(height: 12), Center(child: Text('@${_username.text}', style: const TextStyle(fontWeight: FontWeight.w800))), const SizedBox(height: 22), Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('$_posts منشور', style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(width: 24), const Text('عضو في مجتمع ذكر')]), const SizedBox(height: 24), TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم الظاهر', prefixIcon: Icon(Icons.badge_outlined))), const SizedBox(height: 12), TextField(controller: _username, decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.alternate_email_rounded))), const SizedBox(height: 12), TextField(controller: _bio, maxLines: 3, decoration: const InputDecoration(labelText: 'نبذة عنك', prefixIcon: Icon(Icons.notes_rounded))), const SizedBox(height: 18), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'يحفظ...' : 'حفظ التعديلات'))), const SizedBox(height: 8), TextButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout_rounded), label: const Text('تسجيل الخروج'))])); }
}

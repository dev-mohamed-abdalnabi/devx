import 'package:flutter/material.dart';

import '../../services/supabase_config.dart';
import 'community_utils.dart';

class CommunityAccountScreen extends StatefulWidget {
  const CommunityAccountScreen({super.key});
  @override
  State<CommunityAccountScreen> createState() => _CommunityAccountScreenState();
}

class _CommunityAccountScreenState extends State<CommunityAccountScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  int _posts = 0;
  int _followers = 0;
  int _following = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = supabase.auth.currentUser?.id;
    if (id == null) return;
    try {
      final profile =
          await supabase.from('profiles').select().eq('id', id).single();
      final posts =
          await supabase.from('posts').select('id').eq('author_id', id);
      final followers = await supabase
          .from('follows')
          .select('follower_id')
          .eq('following_id', id);
      final following = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', id);
      _name.text = profile['full_name']?.toString() ?? '';
      _username.text = profile['username']?.toString() ?? '';
      _bio.text = profile['bio']?.toString() ?? '';
      if (mounted) {
        setState(() {
          _posts = (posts as List).length;
          _followers = (followers as List).length;
          _following = (following as List).length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_username.text.trim().length < 3) {
      _message('اسم المستخدم 3 أحرف على الأقل.');
      return;
    }
    setState(() => _saving = true);
    try {
      await supabase.from('profiles').update({
        'full_name': _name.text.trim(),
        'username': _username.text.trim().toLowerCase(),
        'bio': _bio.text.trim(),
      }).eq('id', supabase.auth.currentUser!.id);
      if (mounted) _message('تم حفظ بيانات حسابك.');
    } catch (_) {
      if (mounted) _message('اسم المستخدم مستخدم أو تعذر الحفظ.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            color: Theme.of(ctx).colorScheme.error, size: 36),
        title: const Text('مسح الحساب نهائيًا؟'),
        content: const Text(
            'سيتم حذف حسابك وكل منشوراتك وتعليقاتك وجروباتك ومتابعاتك. لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مسح الحساب'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      await supabase.rpc('delete_my_account');
      try {
        await supabase.auth.signOut();
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم مسح حسابك.')));
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        _message('تعذر مسح الحساب. حاول مرة أخرى.');
      }
    }
  }

  void _message(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Widget _stat(String value, String label) => Expanded(
        child: Column(children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown =
        _name.text.trim().isNotEmpty ? _name.text.trim() : _username.text;
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(initialOf(shown),
                      style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                  child: Text(shown,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800))),
              Center(child: Text('@${_username.text}')),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: scheme.primaryContainer.withOpacity(.45),
                    borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  _stat('$_posts', 'منشور'),
                  _stat('$_followers', 'متابِع'),
                  _stat('$_following', 'يتابع'),
                ]),
              ),
              const SizedBox(height: 22),
              TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'الاسم الظاهر',
                      prefixIcon: Icon(Icons.badge_outlined))),
              const SizedBox(height: 12),
              TextField(
                  controller: _username,
                  decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      prefixIcon: Icon(Icons.alternate_email_rounded))),
              const SizedBox(height: 12),
              TextField(
                  controller: _bio,
                  maxLines: 3,
                  maxLength: 280,
                  decoration: const InputDecoration(
                      labelText: 'نبذة عنك',
                      prefixIcon: Icon(Icons.notes_rounded))),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'يحفظ...' : 'حفظ التعديلات')),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('تسجيل الخروج')),
              ),
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 8),
              Text('منطقة الخطر',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: scheme.error)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error)),
                  onPressed: _deleting ? null : _deleteAccount,
                  icon: _deleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete_forever_rounded),
                  label: const Text('مسح الحساب نهائيًا'),
                ),
              ),
              const SizedBox(height: 24),
            ]),
    );
  }
}

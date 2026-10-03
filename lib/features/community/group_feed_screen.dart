import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_config.dart';
import '../../widgets/app_ui.dart';
import 'auth_screen.dart';
import 'community_utils.dart';

class GroupFeedScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  const GroupFeedScreen({super.key, required this.group});

  @override
  State<GroupFeedScreen> createState() => _GroupFeedScreenState();
}

class _GroupFeedScreenState extends State<GroupFeedScreen> {
  final _composer = TextEditingController();
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _posting = false;
  bool _isMember = false;
  bool _isAdmin = false;

  String get _groupId => widget.group['id'].toString();
  String? get _userId => supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await supabase
          .from('posts')
          .select('*, profiles!posts_author_id_fkey(username, full_name)')
          .eq('group_id', _groupId)
          .eq('visibility', 'group')
          .order('created_at', ascending: false)
          .limit(100);
      final userId = _userId;
      var member = false;
      var admin = false;
      if (userId != null) {
        final membership = await supabase
            .from('group_members')
            .select('status')
            .eq('group_id', _groupId)
            .eq('user_id', userId)
            .maybeSingle();
        member = membership?['status'] == 'active' ||
            widget.group['owner_id'].toString() == userId;
        final profile = await supabase
            .from('profiles')
            .select('is_admin')
            .eq('id', userId)
            .maybeSingle();
        admin = profile?['is_admin'] == true;
      }
      if (!mounted) return;
      setState(() {
        _posts = (rows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _isMember = member;
        _isAdmin = admin;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _requireMember() async {
    if (_userId == null) {
      final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const CommunityAuthScreen()));
      if (result == true && mounted) await _load();
    }
    if (!_isMember) _toast('انضم إلى الجروب أولًا للمشاركة.');
    return _isMember;
  }

  Future<void> _createPost() async {
    if (!await _requireMember()) return;
    final body = _composer.text.trim();
    if (body.isEmpty) {
      _toast('اكتب شيئًا قبل النشر.');
      return;
    }
    setState(() => _posting = true);
    try {
      await supabase.from('posts').insert({
        'author_id': _userId,
        'body': body,
        'visibility': 'group',
        'group_id': _groupId,
      });
      _composer.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      await _load();
    } on PostgrestException catch (e) {
      _toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> post) async {
    final canDelete = _isAdmin || post['author_id'].toString() == _userId;
    if (!canDelete) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنشور؟'),
        content: const Text('سيُحذف المنشور وتعليقاته نهائيًا.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // صلاحية الحذف الحقيقية في RLS: الكاتب أو admin فقط.
      await supabase.from('posts').delete().eq('id', post['id']);
      if (mounted)
        setState(() => _posts.removeWhere((p) => p['id'] == post['id']));
    } on PostgrestException catch (e) {
      _toast(e.message, error: true);
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null));
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.group['name']?.toString() ?? 'الجروب';
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: AppCard(
              pattern: true,
              child: Row(children: [
                const AppIconBadge(icon: Icons.groups_rounded, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      widget.group['description']?.toString().isNotEmpty == true
                          ? widget.group['description'].toString()
                          : 'منشورات أعضاء $name',
                      style: const TextStyle(height: 1.5)),
                ),
              ]),
            ),
          ),
          if (_userId != null && !_isMember)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text('انضم إلى الجروب من صفحة الجروبات حتى تستطيع النشر.'),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _posts.isEmpty
                        ? ListView(children: const [
                            AppEmptyState(
                              icon: Icons.forum_outlined,
                              title: 'لا توجد منشورات بعد',
                              message:
                                  'كن أول من يشارك منشورًا داخل هذا الجروب.',
                            )
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: _posts.length,
                            itemBuilder: (_, index) => _PostCard(
                              post: _posts[index],
                              canDelete: _isAdmin ||
                                  _posts[index]['author_id'].toString() ==
                                      _userId,
                              onDelete: () => _delete(_posts[index]),
                            ),
                          ),
                  ),
          ),
          if (_isMember)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 5000,
                      decoration: const InputDecoration(
                          hintText: 'اكتب منشورًا للجروب...', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _posting ? null : _createPost,
                    icon: _posting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool canDelete;
  final VoidCallback onDelete;
  const _PostCard(
      {required this.post, required this.canDelete, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final profile = (post['profiles'] as Map?)?.cast<String, dynamic>() ?? {};
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const AppIconBadge(icon: Icons.person_rounded, size: 38),
            const SizedBox(width: 10),
            Expanded(
                child: Text(displayName(profile),
                    style: const TextStyle(fontWeight: FontWeight.w800))),
            if (canDelete)
              IconButton(
                  tooltip: 'حذف',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded)),
          ]),
          const SizedBox(height: 10),
          SelectableText(post['body']?.toString() ?? '',
              style: const TextStyle(fontSize: 16, height: 1.7)),
        ]),
      ),
    );
  }
}

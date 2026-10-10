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
  bool _isModerator = false;
  String? _membershipStatus;
  List<Map<String, dynamic>> _pendingMembers = [];

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
      final userId = _userId;
      var member = false;
      var admin = false;
      String? membershipStatus;
      var pending = <Map<String, dynamic>>[];
      if (userId != null) {
        final membership = await supabase
            .from('group_members')
            .select('status, role')
            .eq('group_id', _groupId)
            .eq('user_id', userId)
            .maybeSingle();
        membershipStatus = membership?['status']?.toString();
        _isModerator = membership?['status'] == 'active' &&
            membership?['role'] == 'moderator';
        member = membership?['status'] == 'active' ||
            widget.group['owner_id'].toString() == userId;
        final profile = await supabase
            .from('profiles')
            .select('is_admin')
            .eq('id', userId)
            .maybeSingle();
        admin = profile?['is_admin'] == true;
      }
      // لا نطلب منشورات الجروب الخاص قبل التأكد من العضوية النشطة.
      final canReadPosts = widget.group['is_private'] != true || member;
      final rows = canReadPosts
          ? await supabase
              .from('posts')
              .select('*, profiles!posts_author_id_fkey(username, full_name)')
              .eq('group_id', _groupId)
              .eq('visibility', 'group')
              .order('created_at', ascending: false)
              .limit(100)
          : <Map<String, dynamic>>[];
      final isOwner = widget.group['owner_id'].toString() == userId;
      if (isOwner || _isModerator) {
        final pendingRows = await supabase
            .from('group_members')
            .select('user_id, role, status, profiles!group_members_user_id_fkey(username, full_name)')
            .eq('group_id', _groupId)
            .eq('status', 'pending');
        pending = (pendingRows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _posts = (rows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _isMember = member;
        _isAdmin = admin;
        _membershipStatus = membershipStatus;
        _pendingMembers = pending;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _posts = [];
          _pendingMembers = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _setMemberStatus(String userId, String status) async {
    final isOwner = widget.group['owner_id'].toString() == _userId;
    if (!isOwner && !_isModerator) {
      _toast('لا تملك صلاحية مراجعة طلبات الانضمام.', error: true);
      return;
    }
    try {
      await supabase.rpc('approve_group_membership', params: {
        'p_group_id': _groupId,
        'p_target_user_id': userId,
        'p_status': status,
      });
      await _load();
      _toast(status == 'active' ? 'تمت الموافقة على طلب الانضمام.' : 'تم رفض الطلب.');
    } on PostgrestException catch (e) {
      _toast(e.message, error: true);
    }
  }

  Future<void> _showPrivateCode() async {
    try {
      final code = await supabase.rpc('get_private_group_daily_code', params: {
        'p_group_id': _groupId,
      });
      _toast('كود الجروب اليوم: $code');
    } on PostgrestException catch (e) {
      _toast(e.message, error: true);
    }
  }

  Future<void> _joinGroup() async {
    if (_userId == null) {
      await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const CommunityAuthScreen()));
      if (mounted) await _load();
      return;
    }
    try {
      await supabase.from('group_members').insert({
        'group_id': _groupId,
        'user_id': _userId,
        'role': 'member',
        'status': widget.group['is_private'] == true ? 'pending' : 'active',
      });
      await _load();
      _toast(widget.group['is_private'] == true
          ? 'تم إرسال طلب الانضمام للمشرف.'
          : 'تم انضمامك للجروب ويمكنك الكتابة الآن.');
    } on PostgrestException catch (e) {
      _toast(e.code == pgUniqueViolation
          ? 'طلبك موجود بالفعل أو أنت عضو في الجروب.'
          : 'تعذر تنفيذ طلب الانضمام الآن.', error: true);
    }
  }

  Future<bool> _requireMember() async {
    if (_userId == null) {
      final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const CommunityAuthScreen()));
      if (result == true && mounted) await _load();
    }
    if (!_isMember) {
      final message = switch (_membershipStatus) {
        'pending' => 'طلبك قيد المراجعة؛ ستتمكن من النشر بعد الموافقة.',
        'blocked' => 'لا يمكنك النشر في هذا الجروب حاليًا.',
        _ => 'انضم إلى الجروب أولًا حتى تتمكن من قراءة وكتابة المنشورات.',
      };
      _toast(message);
    }
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
      if (mounted) {
        setState(() => _posts.removeWhere((p) => p['id'] == post['id']));
      }
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
          if (widget.group['is_private'] == true &&
              (widget.group['owner_id']?.toString() == _userId || _isModerator))
            IconButton(
              tooltip: 'كود الجروب اليوم',
              onPressed: _showPrivateCode,
              icon: const Icon(Icons.pin_outlined),
            ),
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
              child: Text('محتوى الجروب الخاص مقفول حتى تتم الموافقة على طلبك.'),
            ),
          if (_pendingMembers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('طلبات الانضمام', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  for (final member in _pendingMembers)
                    Row(children: [
                      Expanded(child: Text(displayName((member['profiles'] as Map?)?.cast<String, dynamic>() ?? {}))),
                      IconButton(
                        tooltip: 'موافقة',
                        onPressed: () => _setMemberStatus(member['user_id'].toString(), 'active'),
                        icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                      ),
                      IconButton(
                        tooltip: 'رفض',
                        onPressed: () => _setMemberStatus(member['user_id'].toString(), 'blocked'),
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                      ),
                    ]),
                ]),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _posts.isEmpty
                        ? ListView(children: [
                            AppEmptyState(
                              icon: widget.group['is_private'] == true && !_isMember
                                  ? Icons.lock_outline
                                  : Icons.forum_outlined,
                              title: widget.group['is_private'] == true && !_isMember
                                  ? 'المحتوى غير متاح بعد'
                                  : 'لا توجد منشورات بعد',
                              message: widget.group['is_private'] == true && !_isMember
                                  ? 'سيظهر المحتوى بعد قبول طلب انضمامك من صاحب الجروب.'
                                  : 'كن أول من يشارك منشورًا داخل هذا الجروب.',
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
          if (!_isMember && _userId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(children: [
                Expanded(
                    child: Text(widget.group['is_private'] == true
                        ? (_membershipStatus == 'pending'
                            ? 'طلبك قيد المراجعة من صاحب الجروب.'
                            : 'اطلب الانضمام لرؤية محتوى الجروب الخاص.')
                        : 'يمكنك القراءة الآن؛ انضم للجروب حتى تتمكن من الكتابة.')),
                if (!(widget.group['is_private'] == true &&
                    _membershipStatus == 'pending'))
                  FilledButton.tonal(
                      onPressed: _membershipStatus == 'blocked' ? null : _joinGroup,
                      child: Text(widget.group['is_private'] == true
                          ? 'طلب انضمام'
                          : 'انضمام')),
              ]),
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
            CircleAvatar(
              radius: 19,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(initialOf(displayName(profile)),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(displayName(profile),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(timeAgo(post['created_at']?.toString()),
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ])),
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

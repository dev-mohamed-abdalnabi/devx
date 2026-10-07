import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_config.dart';
import '../../widgets/app_ui.dart';
import 'account_screen.dart';
import 'auth_screen.dart';
import 'community_utils.dart';
import 'groups_screen.dart';
import 'notifications_screen.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});
  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  static const _pageSize = 20;

  /// 0 = الكل، 1 = المتابَعون، 2 = الجروبات
  int _section = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _posting = false;
  int _unread = 0;
  int _loadToken = 0;
  List<Map<String, dynamic>> _posts = [];
  final _composer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  // ───────────────────────── تحميل البيانات ─────────────────────────

  Future<List<Map<String, dynamic>>> _fetchPage(int offset) async {
    final userId = supabase.auth.currentUser?.id;
    List<String>? authorFilter;
    if (_section == 1) {
      if (userId == null) return [];
      final f = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);
      authorFilter = [
        userId,
        ...(f as List).map((e) => e['following_id'].toString()),
      ];
    }
    final base = supabase
        .from('posts')
        .select('*, profiles!posts_author_id_fkey(username, full_name)')
        // الفيد العام لا يعرض منشورات الجروبات تحت أي ظرف؛ مكانها داخل الجروب فقط.
        .inFilter('visibility', ['public', 'followers']);
    final rows = await (authorFilter == null
            ? base
            : base.inFilter('author_id', authorFilter))
        .order('created_at', ascending: false)
        .range(offset, offset + _pageSize - 1);
    final list =
        (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    if (list.isEmpty || userId == null) {
      for (final p in list) {
        p['liked'] = false;
        p['following'] = false;
      }
      return list;
    }
    final ids = list.map((p) => p['id'].toString()).toList();
    final authors = list.map((p) => p['author_id'].toString()).toSet().toList();
    final likedRows = await supabase
        .from('post_likes')
        .select('post_id')
        .eq('user_id', userId)
        .inFilter('post_id', ids);
    final followRows = await supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId)
        .inFilter('following_id', authors);
    final liked =
        (likedRows as List).map((e) => e['post_id'].toString()).toSet();
    final following =
        (followRows as List).map((e) => e['following_id'].toString()).toSet();
    for (final p in list) {
      p['liked'] = liked.contains(p['id'].toString());
      p['following'] = following.contains(p['author_id'].toString());
    }
    return list;
  }

  Future<void> _loadFeed({bool silent = false}) async {
    if (_section == 2) return;
    final token = ++_loadToken;
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final posts = await _fetchPage(0);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _posts = posts;
        _hasMore = posts.length == _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() => _loading = false);
      _toast('تعذر تحميل المنشورات الآن.', error: true);
    }
    _loadUnread();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final token = _loadToken;
    setState(() => _loadingMore = true);
    try {
      final more = await _fetchPage(_posts.length);
      if (!mounted || token != _loadToken) return;
      final known = _posts.map((p) => p['id'].toString()).toSet();
      setState(() {
        _posts.addAll(more.where((p) => !known.contains(p['id'].toString())));
        _hasMore = more.length == _pageSize;
      });
    } catch (_) {
      if (mounted) _toast('تعذر تحميل المزيد.', error: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadUnread() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted && _unread != 0) setState(() => _unread = 0);
      return;
    }
    try {
      final rows = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .limit(100);
      if (mounted) setState(() => _unread = (rows as List).length);
    } catch (_) {}
  }

  void _changeSection(int value) {
    if (value == _section) return;
    setState(() {
      _section = value;
      _posts = [];
      _hasMore = false;
    });
    if (value != 2) _loadFeed();
  }

  // ───────────────────────── الإجراءات ─────────────────────────

  Future<bool> _requireAuth({bool signUp = false}) async {
    if (supabase.auth.currentUser != null) return true;
    final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => CommunityAuthScreen(signUp: signUp)));
    if (result == true && mounted) await _loadFeed();
    return result == true;
  }

  Future<void> _createPost() async {
    if (!await _requireAuth()) return;
    final body = _composer.text.trim();
    if (body.isEmpty) {
      _toast('اكتب شيئًا قبل النشر.');
      return;
    }
    setState(() => _posting = true);
    try {
      await supabase.from('posts').insert({
        'author_id': supabase.auth.currentUser!.id,
        'body': body,
        'visibility': 'public',
      });
      _composer.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      if (_section != 0) {
        setState(() => _section = 0);
      }
      await _loadFeed(silent: true);
      if (mounted) _toast('تم نشر كلامك في المنتدى.');
    } on PostgrestException catch (e) {
      if (mounted) _toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  /// تحديث فوري للشاشة ثم تأكيد من الخادم، والتراجع إذا فشل الطلب.
  Future<void> _toggleLike(Map<String, dynamic> post) async {
    if (!await _requireAuth()) return;
    final id = post['id'].toString();
    final userId = supabase.auth.currentUser!.id;
    final wasLiked = post['liked'] == true;
    final oldCount = (post['like_count'] as int?) ?? 0;
    setState(() {
      post['liked'] = !wasLiked;
      post['like_count'] = math.max(0, oldCount + (wasLiked ? -1 : 1));
    });
    try {
      if (wasLiked) {
        await supabase
            .from('post_likes')
            .delete()
            .match({'post_id': id, 'user_id': userId});
      } else {
        await supabase
            .from('post_likes')
            .insert({'post_id': id, 'user_id': userId});
      }
    } on PostgrestException catch (e) {
      if (e.code == pgUniqueViolation && !wasLiked) return;
      _revertLike(post, wasLiked, oldCount);
    } catch (_) {
      _revertLike(post, wasLiked, oldCount);
    }
  }

  void _revertLike(Map<String, dynamic> post, bool wasLiked, int oldCount) {
    if (!mounted) return;
    setState(() {
      post['liked'] = wasLiked;
      post['like_count'] = oldCount;
    });
    _toast('تعذر تحديث التفاعل.', error: true);
  }

  Future<void> _share(Map<String, dynamic> post) async {
    if (!await _requireAuth()) return;
    try {
      await supabase.from('post_shares').insert({
        'post_id': post['id'],
        'user_id': supabase.auth.currentUser!.id,
      });
      if (!mounted) return;
      setState(
          () => post['share_count'] = ((post['share_count'] as int?) ?? 0) + 1);
      _toast('تمت مشاركة المنشور في ملفك.');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _toast(
          e.code == pgUniqueViolation
              ? 'شاركت هذا المنشور من قبل.'
              : 'تعذرت المشاركة الآن.',
          error: e.code != pgUniqueViolation);
    } catch (_) {
      if (mounted) _toast('تعذرت المشاركة الآن.', error: true);
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> post) async {
    if (!await _requireAuth()) return;
    final userId = supabase.auth.currentUser!.id;
    final authorId = post['author_id'].toString();
    if (authorId == userId) return;
    final wasFollowing = post['following'] == true;
    void apply(bool value) {
      for (final p in _posts) {
        if (p['author_id'].toString() == authorId) p['following'] = value;
      }
    }

    setState(() => apply(!wasFollowing));
    try {
      if (wasFollowing) {
        await supabase
            .from('follows')
            .delete()
            .match({'follower_id': userId, 'following_id': authorId});
      } else {
        await supabase
            .from('follows')
            .insert({'follower_id': userId, 'following_id': authorId});
      }
      if (mounted) {
        _toast(wasFollowing
            ? 'تم إيقاف الجرس.'
            : 'تم تفعيل الجرس 🔔 هتوصلك إشعارات بمنشوراته.');
      }
    } on PostgrestException catch (e) {
      if (e.code == pgUniqueViolation && !wasFollowing) return;
      if (mounted) {
        setState(() => apply(wasFollowing));
        _toast('تعذر تحديث المتابعة.', error: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => apply(wasFollowing));
        _toast('تعذر تحديث المتابعة.', error: true);
      }
    }
  }

  Future<void> _report(Map<String, dynamic> post) async {
    if (!await _requireAuth()) return;
    if (!mounted) return;
    final reason = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (_) => const _ReportSheet());
    if (reason == null) return;
    try {
      await supabase.from('reports').insert({
        'reporter_id': supabase.auth.currentUser!.id,
        'post_id': post['id'],
        'reason': reason,
      });
      if (mounted) _toast('وصل بلاغك وسيراجعه فريق الإشراف.');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _toast(
          e.code == pgUniqueViolation
              ? 'سبق أن أبلغت عن هذا المنشور.'
              : 'تعذر إرسال البلاغ.',
          error: e.code != pgUniqueViolation);
    } catch (_) {
      if (mounted) _toast('تعذر إرسال البلاغ.', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> post) async {
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
      await supabase.from('posts').delete().eq('id', post['id']);
      if (!mounted) return;
      setState(() => _posts.removeWhere((p) => p['id'] == post['id']));
      _toast('تم حذف المنشور.');
    } catch (_) {
      if (mounted) _toast('تعذر حذف المنشور.', error: true);
    }
  }

  Future<void> _copy(Map<String, dynamic> post) async {
    await Clipboard.setData(
        ClipboardData(text: post['body']?.toString() ?? ''));
    if (mounted) _toast('تم نسخ النص.');
  }

  Future<void> _openComments(Map<String, dynamic> post) async {
    if (!await _requireAuth()) return;
    if (!mounted) return;
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _CommentsSheet(post: post));
    // عدّاد التعليقات فقط، بدون إعادة تحميل الصفحة كلها.
    try {
      final row = await supabase
          .from('posts')
          .select('comment_count')
          .eq('id', post['id'])
          .single();
      if (mounted) setState(() => post['comment_count'] = row['comment_count']);
    } catch (_) {}
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null));
  }

  Future<void> _openAccount() async {
    if (!await _requireAuth()) return;
    if (!mounted) return;
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CommunityAccountScreen()));
    if (mounted) setState(() {});
    _loadFeed(silent: true);
  }

  Future<void> _openNotifications() async {
    if (!await _requireAuth()) return;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const CommunityNotificationsScreen()));
    _loadUnread();
  }

  // ───────────────────────── الواجهة ─────────────────────────

  Widget _emptyForSection() {
    if (_section == 1 && supabase.auth.currentUser == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(children: [
            const AppEmptyState(
                icon: Icons.person_add_alt_1_outlined,
                title: 'تابع من تهتم بكلامهم',
                message: 'سجّل دخولك لترى منشورات من تتابعهم هنا.'),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: () => _requireAuth(signUp: true),
                icon: const Icon(Icons.login_rounded),
                label: const Text('دخول')),
          ]),
        ),
      );
    }
    if (_section == 1) {
      return const SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
              icon: Icons.people_outline,
              title: 'لا توجد منشورات من حسابات الجرس',
              message:
                  'فعّل الجرس 🔔 على أي عضو من تبويب «الكل» لتظهر منشوراته هنا وتصلك إشعارات بها.'));
    }
    return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
            icon: Icons.forum_outlined,
            title: 'المنتدى ينتظر كلمتك',
            message: 'كن أول من يشارك فكرة طيبة أو فائدة نافعة.'));
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          if (_section == 2) return;
          await _loadFeed(silent: true);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
                child: _ForumHeader(
              user: user,
              unread: _unread,
              onProfile: _openAccount,
              onNotifications: _openNotifications,
              onRefresh: () => _loadFeed(),
            )),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.public_rounded, size: 18),
                        label: Text('الكل')),
                    ButtonSegment(
                        value: 1,
                        icon:
                            Icon(Icons.notifications_active_outlined, size: 18),
                        label: Text('جرسي')),
                    ButtonSegment(
                        value: 2,
                        icon: Icon(Icons.groups_rounded, size: 18),
                        label: Text('الجروبات')),
                  ],
                  selected: {_section},
                  onSelectionChanged: (s) => _changeSection(s.first),
                ),
              ),
            ),
            if (_section == 2)
              const SliverFillRemaining(child: GroupsScreen())
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: _Composer(
                    controller: _composer,
                    onPost: _createPost,
                    loading: _posting,
                    signedIn: user != null,
                    onSignIn: () => _requireAuth(signUp: true),
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()))
              else if (_posts.isEmpty)
                _emptyForSection()
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SliverList.builder(
                    itemCount: _posts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _posts.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Center(
                            child: _loadingMore
                                ? const CircularProgressIndicator()
                                : OutlinedButton.icon(
                                    onPressed: _loadMore,
                                    icon: const Icon(Icons.expand_more_rounded),
                                    label: const Text('تحميل المزيد')),
                          ),
                        );
                      }
                      final post = _posts[i];
                      return _PostCard(
                        key: ValueKey(post['id']),
                        post: post,
                        isMine: post['author_id'] == user?.id,
                        onLike: () => _toggleLike(post),
                        onComment: () => _openComments(post),
                        onShare: () => _share(post),
                        onReport: () => _report(post),
                        onFollow: () => _toggleFollow(post),
                        onDelete: () => _delete(post),
                        onCopy: () => _copy(post),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ForumHeader extends StatelessWidget {
  final User? user;
  final int unread;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;
  final VoidCallback onRefresh;
  const _ForumHeader({
    required this.user,
    required this.unread,
    required this.onProfile,
    required this.onNotifications,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16)),
          child: Icon(Icons.forum_rounded, color: scheme.primary, size: 27),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('المنتدى',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text('كلمة طيبة، أثر جميل', style: TextStyle(fontSize: 13)),
          ]),
        ),
        IconButton(
          tooltip: 'الإشعارات',
          onPressed: onNotifications,
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        IconButton(
            tooltip: 'تحديث',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded)),
        IconButton(
            tooltip: user == null ? 'دخول' : 'حسابي',
            onPressed: onProfile,
            icon: Icon(user == null
                ? Icons.login_rounded
                : Icons.account_circle_outlined)),
      ]),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onPost;
  final VoidCallback onSignIn;
  final bool loading;
  final bool signedIn;
  const _Composer({
    required this.controller,
    required this.onPost,
    required this.loading,
    required this.signedIn,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: controller,
          minLines: 2,
          maxLines: 6,
          maxLength: 5000,
          enabled: signedIn,
          buildCounter: (_,
                  {required currentLength, required isFocused, maxLength}) =>
              null,
          decoration: InputDecoration(
            hintText: signedIn
                ? 'شارك ما ينفع الناس...'
                : 'سجّل دخولك لتكتب في المنتدى',
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withOpacity(.5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            onPressed: signedIn ? (loading ? null : onPost) : onSignIn,
            icon: Icon(signedIn ? Icons.send_rounded : Icons.login_rounded,
                size: 18),
            label: Text(signedIn ? (loading ? 'ينشر...' : 'نشر') : 'دخول'),
          ),
        ),
      ]),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isMine;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback onFollow;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  const _PostCard({
    super.key,
    required this.post,
    required this.isMine,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onReport,
    required this.onFollow,
    required this.onDelete,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final profile = (post['profiles'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = displayName(profile);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final liked = post['liked'] == true;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: scheme.primary.withOpacity(.5), width: 1.5)),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: scheme.primaryContainer,
                child: Text(initialOf(name),
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                        '@${profile['username'] ?? 'member'} · ${timeAgo(post['created_at']?.toString())}',
                        style: muted),
                  ]),
            ),
            if (!isMine)
              IconButton(
                tooltip: post['following'] == true
                    ? 'إيقاف إشعارات هذا الحساب'
                    : 'فعّل الجرس لتصلك منشوراته',
                onPressed: onFollow,
                icon: Icon(
                    post['following'] == true
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    color: post['following'] == true ? scheme.primary : null),
              ),
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'copy':
                    onCopy();
                  case 'report':
                    onReport();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'copy',
                    child: ListTile(
                        leading: Icon(Icons.copy_rounded),
                        title: Text('نسخ النص'))),
                if (isMine)
                  const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('حذف المنشور')))
                else
                  const PopupMenuItem(
                      value: 'report',
                      child: ListTile(
                          leading: Icon(Icons.flag_outlined),
                          title: Text('إبلاغ عن المنشور'))),
              ],
            ),
          ]),
          const SizedBox(height: 14),
          Text(post['body']?.toString() ?? '',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(height: 1.65)),
          const SizedBox(height: 10),
          Divider(height: 1, color: scheme.outlineVariant.withOpacity(.6)),
          const SizedBox(height: 2),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _Action(
                icon: liked ? Icons.favorite : Icons.favorite_border,
                label: '${post['like_count'] ?? 0}',
                active: liked,
                onTap: onLike),
            _Action(
                icon: Icons.mode_comment_outlined,
                label: '${post['comment_count'] ?? 0}',
                onTap: onComment),
            _Action(
                icon: Icons.repeat_rounded,
                label: '${post['share_count'] ?? 0}',
                onTap: onShare),
          ]),
        ]),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _Action(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.active = false});

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.error : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  const _CommentsSheet({required this.post});
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  List<Map<String, dynamic>> _comments = [];
  Set<String> _liked = {};
  Map<String, dynamic>? _replyTo; // التعليق الذي نرد عليه
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await supabase
          .from('comments')
          .select('*, profiles!comments_author_id_fkey(username, full_name)')
          .eq('post_id', widget.post['id'])
          .order('created_at');
      final list = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final me = supabase.auth.currentUser?.id;
      var liked = <String>{};
      if (me != null && list.isNotEmpty) {
        final rows = await supabase
            .from('comment_likes')
            .select('comment_id')
            .eq('user_id', me)
            .inFilter(
                'comment_id', list.map((c) => c['id'].toString()).toList());
        liked = (rows as List).map((e) => e['comment_id'].toString()).toSet();
      }
      if (!mounted) return;
      setState(() {
        _comments = list;
        _liked = liked;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await supabase.from('comments').insert({
        'post_id': widget.post['id'],
        'author_id': supabase.auth.currentUser!.id,
        'body': text,
        if (_replyTo != null) 'parent_id': _replyTo!['id'],
      });
      _controller.clear();
      _replyTo = null;
      await _load();
    } catch (_) {
      _snack('تعذر نشر التعليق.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> c) async {
    final me = supabase.auth.currentUser?.id;
    if (me == null) return;
    final id = c['id'].toString();
    final was = _liked.contains(id);
    setState(() {
      was ? _liked.remove(id) : _liked.add(id);
      c['like_count'] = ((c['like_count'] ?? 0) as int) + (was ? -1 : 1);
    });
    try {
      if (was) {
        await supabase
            .from('comment_likes')
            .delete()
            .match({'comment_id': id, 'user_id': me});
      } else {
        await supabase
            .from('comment_likes')
            .insert({'comment_id': id, 'user_id': me});
      }
    } on PostgrestException catch (e) {
      if (e.code == pgUniqueViolation && !was) return;
      _revertLike(c, id, was);
    } catch (_) {
      _revertLike(c, id, was);
    }
  }

  void _revertLike(Map<String, dynamic> c, String id, bool was) {
    if (!mounted) return;
    setState(() {
      was ? _liked.add(id) : _liked.remove(id);
      c['like_count'] = ((c['like_count'] ?? 0) as int) + (was ? 1 : -1);
    });
    _snack('تعذر تحديث الإعجاب.');
  }

  Future<void> _deleteComment(Map<String, dynamic> c) async {
    try {
      await supabase.from('comments').delete().eq('id', c['id']);
      await _load();
    } catch (_) {
      _snack('تعذر حذف التعليق.');
    }
  }

  void _startReply(Map<String, dynamic> c) {
    // الرد على رد يتجمع تحت التعليق الأصلي (مستوى واحد زي فيسبوك).
    final root = c['parent_id'] == null
        ? c
        : _comments.firstWhere((x) => x['id'] == c['parent_id'],
            orElse: () => c);
    final p = (c['profiles'] as Map?)?.cast<String, dynamic>();
    setState(() => _replyTo = {...root, 'reply_name': displayName(p)});
    _focus.requestFocus();
  }

  void _snack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Widget _tile(Map<String, dynamic> c, {required bool isReply}) {
    final me = supabase.auth.currentUser?.id;
    final scheme = Theme.of(context).colorScheme;
    final p = (c['profiles'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = displayName(p);
    final liked = _liked.contains(c['id'].toString());
    final likes = (c['like_count'] ?? 0) as int;
    final small = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: scheme.onSurfaceVariant);
    return Padding(
      padding: EdgeInsets.only(top: 10, right: isReply ? 0 : 0, left: 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: isReply ? 14 : 18,
          backgroundColor: scheme.primaryContainer,
          child: Text(initialOf(name),
              style: TextStyle(
                  fontSize: isReply ? 11 : 14, color: scheme.primary)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
              decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withOpacity(.6),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(c['body']?.toString() ?? '',
                        style: const TextStyle(height: 1.5)),
                  ]),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 6, left: 6),
              child: Row(children: [
                Text(timeAgo(c['created_at']?.toString()),
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant)),
                const SizedBox(width: 14),
                InkWell(
                    onTap: () => _toggleLike(c),
                    child: Text(likes > 0 ? 'أعجبني · $likes' : 'أعجبني',
                        style: small.copyWith(
                            color: liked ? scheme.error : null))),
                const SizedBox(width: 14),
                InkWell(
                    onTap: () => _startReply(c),
                    child: Text('رد', style: small)),
                if (c['author_id'] == me) ...[
                  const SizedBox(width: 14),
                  InkWell(
                      onTap: () => _deleteComment(c),
                      child: Text('حذف', style: small)),
                ],
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final screen = MediaQuery.sizeOf(context).height;
    final scheme = Theme.of(context).colorScheme;
    final roots = _comments.where((c) => c['parent_id'] == null).toList();
    final replies = <String, List<Map<String, dynamic>>>{};
    for (final c in _comments) {
      final pid = c['parent_id']?.toString();
      if (pid != null) replies.putIfAbsent(pid, () => []).add(c);
    }
    return Padding(
      // يرفع حقل التعليق فوق الكيبورد بدل ما يختفي خلفه
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SizedBox(
          height: math.min(screen * .78, screen - bottom - 90),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(children: [
              Text('التعليقات (${_comments.length})',
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : roots.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.chat_bubble_outline,
                            title: 'لا توجد تعليقات بعد',
                            message: 'ابدأ نقاشًا نافعًا ومحترمًا.')
                        : ListView.builder(
                            itemCount: roots.length,
                            itemBuilder: (_, i) {
                              final c = roots[i];
                              final kids = replies[c['id'].toString()] ?? [];
                              return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _tile(c, isReply: false),
                                    if (kids.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                                start: 34),
                                        child: Container(
                                          decoration: BoxDecoration(
                                              border: BorderDirectional(
                                                  start: BorderSide(
                                                      color:
                                                          scheme.outlineVariant,
                                                      width: 2))),
                                          padding:
                                              const EdgeInsetsDirectional.only(
                                                  start: 8),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                for (final r in kids)
                                                  _tile(r, isReply: true),
                                              ]),
                                        ),
                                      ),
                                  ]);
                            }),
              ),
              if (_replyTo != null)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                      color: scheme.primaryContainer.withOpacity(.5),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(
                        child: Text('رد على ${_replyTo!['reply_name']}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700))),
                    InkWell(
                        onTap: () => setState(() => _replyTo = null),
                        child: const Icon(Icons.close_rounded, size: 18)),
                  ]),
                ),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 2000,
                    buildCounter: (_,
                            {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        null,
                    decoration: InputDecoration(
                      hintText:
                          _replyTo == null ? 'اكتب تعليقًا...' : 'اكتب ردك...',
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withOpacity(.5),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet();

  @override
  Widget build(BuildContext context) {
    const options = {
      'spam': 'محتوى مزعج أو ترويجي',
      'harassment': 'إساءة أو تنمر',
      'hate': 'خطاب كراهية',
      'misinformation': 'معلومة مضللة',
      'inappropriate': 'محتوى غير مناسب',
      'other': 'سبب آخر',
    };
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        children: [
          const Text('لماذا تريد الإبلاغ؟',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...options.entries.map((e) => ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(e.value),
              onTap: () => Navigator.pop(context, e.key))),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_config.dart';
import '../../core/home_tokens.dart';
import '../../widgets/home_style.dart';
import '../home/home_art.dart';
import 'account_screen.dart';
import 'auth_screen.dart';
import 'community_utils.dart';
import 'groups_screen.dart';
import 'notifications_screen.dart';
import '../../services/community_realtime.dart';

class ForumScreen extends StatefulWidget {
  final String? focusPostId;
  const ForumScreen({super.key, this.focusPostId});
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
  Map<String, dynamic>? _myProfile;

  @override
  void initState() {
    super.initState();
    // اتصال المنتدى لا يبدأ مع التطبيق؛ يفتح فقط عند دخول هذه الشاشة.
    CommunityRealtime.start();
    _loadFeed();
    _loadMe();
  }

  Future<void> _loadMe() async {
    final id = supabase.auth.currentUser?.id;
    if (id == null) return;
    try {
      final r = await supabase
          .from('profiles')
          .select('username, full_name')
          .eq('id', id)
          .maybeSingle();
      if (mounted && r != null) setState(() => _myProfile = Map.from(r));
    } catch (_) {}
  }

  @override
  void dispose() {
    CommunityRealtime.stop();
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
      if (widget.focusPostId != null && widget.focusPostId!.isNotEmpty) {
        try {
          final focused = await supabase
              .from('posts')
              .select('*, profiles!posts_author_id_fkey(username, full_name)')
              .eq('id', widget.focusPostId!)
              .maybeSingle();
          if (focused != null &&
              !posts.any((p) => p['id'].toString() == widget.focusPostId)) {
            posts.insert(0, Map<String, dynamic>.from(focused));
          }
        } catch (_) {}
      }
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
    final reason = await showHomeSheet<String>(context,
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
    final ok = await _confirmDialog(context,
        title: 'حذف المنشور؟',
        message: 'سيُحذف المنشور وتعليقاته نهائيًا.',
        confirmLabel: 'حذف');
    if (!ok) return;
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
    await showHomeSheet(context, builder: (_) => _CommentsSheet(post: post));
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
      ..showSnackBar(
          _forumSnack(HomeTokens.of(context), message, error: error));
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

  Widget _emptyForSection(HomeTokens tk) {
    if (_section == 1 && supabase.auth.currentUser == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(children: [
            HomeEmpty(
                tk: tk,
                icon: _Ic.bell,
                title: 'تابع من تهتم بكلامهم',
                message: 'سجّل دخولك لترى منشورات من تتابعهم هنا.'),
            const SizedBox(height: 4),
            SizedBox(
              width: 200,
              child: HomeButton(
                  tk: tk,
                  label: 'دخول',
                  primary: true,
                  onTap: () => _requireAuth(signUp: true)),
            ),
          ]),
        ),
      );
    }
    if (_section == 1) {
      return SliverFillRemaining(
          hasScrollBody: false,
          child: HomeEmpty(
              tk: tk,
              icon: _Ic.bell,
              title: 'لا توجد منشورات من حسابات الجرس',
              message:
                  'فعّل الجرس على أي عضو من تبويب «الكل» لتظهر منشوراته هنا وتصلك إشعارات بها.'));
    }
    return SliverFillRemaining(
        hasScrollBody: false,
        child: HomeEmpty(
            tk: tk,
            icon: HomeIcons.forum,
            title: 'المنتدى ينتظر كلمتك',
            message: 'كن أول من يشارك فكرة طيبة أو فائدة نافعة.'));
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);
    // بدون خلفية خاصة: النقش والخلفية يأتيان من PatternedBackground تحت التابات.
    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: tk.gold,
          backgroundColor: tk.card,
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
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  child: _Tabs(value: _section, onChanged: _changeSection),
                ),
              ),
              if (_section == 2)
                const SliverFillRemaining(child: GroupsScreen())
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                    child: _Composer(
                      controller: _composer,
                      onPost: _createPost,
                      loading: _posting,
                      signedIn: user != null,
                      name: displayName(_myProfile),
                      onSignIn: () => _requireAuth(signUp: true),
                    ),
                  ),
                ),
                if (_loading)
                  SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: tk.gold)))
                else if (_posts.isEmpty)
                  _emptyForSection(tk)
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                    sliver: SliverList.builder(
                      itemCount: _posts.length + (_hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _posts.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Center(
                              child: _loadingMore
                                  ? CircularProgressIndicator(
                                      strokeWidth: 2.5, color: tk.gold)
                                  : SizedBox(
                                      width: 200,
                                      child: HomeButton(
                                          tk: tk,
                                          label: 'تحميل المزيد',
                                          onTap: _loadMore)),
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
      ),
    );
  }
}

// ───────────────────────── أيقونات إضافية (نفس أسلوب أيقونات الرئيسية) ─────────────────────────

class _Ic {
  _Ic._();
  static const bell =
      '<path d="M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15zM10 21h4"/>';
  static const login = '<path d="M14 4h5v16h-5M10 8l4 4-4 4M14 12H4"/>';
  static const send = '<path d="M21 3L10 14M21 3l-7 18-4-7-7-4z"/>';
  static const globe =
      '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18"/>';
  static const users =
      '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.5 3-5.5 6.5-5.5s6.5 2 6.5 5.5M16 4.5a3.5 3.5 0 0 1 0 7M18 14.5c2 .6 3.5 2.2 3.5 5"/>';
  static const trash =
      '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v6M14 11v6"/>';
  static const flag = '<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>';
}

const _heartRed = Color(0xFFE5484D);

// ───────────────────────── مكوّنات الواجهة ─────────────────────────

/// أفاتار نعناعي بحدّ ذهبي رفيع (بدل التدرّجات الملوّنة).
class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  const _Avatar({required this.name, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final t = HomeTokens.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.mint,
        shape: BoxShape.circle,
        border: Border.all(color: t.gold.withValues(alpha: .55)),
      ),
      child: Text(initialOf(name),
          style: cairoStyle(size * .42, weight: 700, color: t.mintInk)),
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
    final t = HomeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageHeader(title: 'المنتدى', actions: [
          Badge(
            isLabelVisible: unread > 0,
            backgroundColor: t.gold,
            textColor: Colors.white,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: HeaderButton(
                icon: _Ic.bell,
                label: 'الإشعارات',
                onTap: onNotifications),
          ),
          HeaderButton(
              icon: ZikrIcons.refresh, label: 'تحديث', onTap: onRefresh),
          HeaderButton(
              icon: user == null ? _Ic.login : ZikrIcons.child,
              label: user == null ? 'دخول' : 'حسابي',
              onTap: onProfile),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
          child: Text('كلمة طيبة، أثر جميل',
              style: cairoStyle(13.5, color: t.muted)),
        ),
      ]),
    );
  }
}

/// تبويبات بشكل شرائح الرئيسية (HomeChip) بعرض متساوٍ.
class _Tabs extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _Tabs({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = HomeTokens.of(context);
    const labels = ['الكل', 'جرسي', 'الجروبات'];
    return Row(children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: HomeChip(
              tk: t,
              label: labels[i],
              selected: value == i,
              onTap: () => onChanged(i)),
        ),
      ],
    ]);
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onPost;
  final VoidCallback onSignIn;
  final bool loading;
  final bool signedIn;
  final String name;
  const _Composer({
    required this.controller,
    required this.onPost,
    required this.loading,
    required this.signedIn,
    required this.onSignIn,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final t = HomeTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.line)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _Avatar(name: signedIn ? name : '؟', size: 38),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 6,
            maxLength: 5000,
            enabled: signedIn,
            cursorColor: t.gold,
            style: cairoStyle(14.5, color: t.ink, height: 1.6),
            buildCounter: (_,
                    {required currentLength, required isFocused, maxLength}) =>
                null,
            decoration: InputDecoration(
              hintText: signedIn
                  ? 'شارك ما ينفع الناس...'
                  : 'سجّل دخولك لتكتب في المنتدى',
              hintStyle: cairoStyle(14, color: t.muted),
              filled: true,
              fillColor: t.bg,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: t.gold.withValues(alpha: .7))),
              disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, v, __) {
            final ready = !signedIn || v.text.trim().isNotEmpty;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: ready ? 1 : .45,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: signedIn ? (loading || !ready ? null : onPost) : onSignIn,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: t.mint,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.leaf)),
                  child: loading
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: t.mintInk))
                      : Center(
                          child: StyledIcon(signedIn ? _Ic.send : _Ic.login,
                              size: 19, color: t.mintInk)),
                ),
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _PostCard extends StatefulWidget {
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
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _expanded = false;

  void _menu() {
    final t = HomeTokens.of(context);
    showHomeSheet(
      context,
      builder: (ctx) => Column(children: [
        HomeSheetRow(
            tk: t,
            icon: ZikrIcons.copy,
            label: 'نسخ النص',
            onTap: () {
              Navigator.pop(ctx);
              widget.onCopy();
            }),
        if (widget.isMine)
          HomeSheetRow(
              tk: t,
              icon: _Ic.trash,
              iconColor: _heartRed,
              label: 'حذف المنشور',
              onTap: () {
                Navigator.pop(ctx);
                widget.onDelete();
              })
        else
          HomeSheetRow(
              tk: t,
              icon: _Ic.flag,
              label: 'إبلاغ عن المنشور',
              onTap: () {
                Navigator.pop(ctx);
                widget.onReport();
              }),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final t = HomeTokens.of(context);
    final profile = (post['profiles'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = displayName(profile);
    final liked = post['liked'] == true;
    final following = post['following'] == true;
    final likes = (post['like_count'] as int?) ?? 0;
    final comments = (post['comment_count'] as int?) ?? 0;
    final shares = (post['share_count'] as int?) ?? 0;
    final body = post['body']?.toString() ?? '';
    final long = body.length > 280 || '\n'.allMatches(body).length > 6;
    final statStyle = cairoStyle(12, weight: 600, color: t.muted);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 0),
          child: Row(children: [
            _Avatar(name: name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: cairoStyle(14.5, weight: 700, color: t.ink)),
                    Text(
                        '@${profile['username'] ?? 'member'} · ${timeAgo(post['created_at']?.toString())}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: cairoStyle(11.5, color: t.muted)),
                  ]),
            ),
            if (!widget.isMine)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onFollow,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: following ? t.mint : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: following
                              ? t.gold
                              : t.gold.withValues(alpha: .55))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    StyledIcon(_Ic.bell,
                        size: 14,
                        color: following ? t.mintInk : t.gold,
                        fill: following ? t.mintInk : null),
                    const SizedBox(width: 4),
                    Text(following ? 'مُفعّل' : 'تابع',
                        style: cairoStyle(11.5,
                            weight: 700,
                            color: following ? t.mintInk : t.gold)),
                  ]),
                ),
              ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _menu,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                    child: StyledIcon(ZikrIcons.dots, size: 20, color: t.muted)),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(body,
                maxLines: (long && !_expanded) ? 6 : null,
                overflow: (long && !_expanded) ? TextOverflow.fade : null,
                style: cairoStyle(15, color: t.ink, height: 1.75)),
            if (long)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_expanded ? 'عرض أقل' : 'عرض المزيد',
                      style: cairoStyle(13, weight: 700, color: t.gold)),
                ),
              ),
          ]),
        ),
        if (likes + comments + shares > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              if (likes > 0) ...[
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                      color: _heartRed, shape: BoxShape.circle),
                  child: const Center(
                      child: StyledIcon(HomeIcons.heart,
                          size: 10, color: Colors.white, fill: Colors.white)),
                ),
                const SizedBox(width: 6),
                Text('$likes', style: statStyle),
              ],
              const Spacer(),
              if (comments > 0) Text('$comments تعليق', style: statStyle),
              if (comments > 0 && shares > 0) Text('  ·  ', style: statStyle),
              if (shares > 0) Text('$shares مشاركة', style: statStyle),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Divider(height: 1, color: t.line),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
          child: Row(children: [
            _Action(
                icon: HomeIcons.heart,
                fill: liked ? _heartRed : null,
                label: 'أعجبني',
                color: liked ? _heartRed : t.muted,
                onTap: widget.onLike),
            _Action(
                icon: HomeIcons.forum,
                label: 'تعليق',
                color: t.muted,
                onTap: widget.onComment),
            _Action(
                icon: ZikrIcons.share,
                label: 'مشاركة',
                color: t.muted,
                onTap: widget.onShare),
          ]),
        ),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  final String icon;
  final Color? fill;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Action(
      {required this.icon,
      this.fill,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            StyledIcon(icon, size: 19, color: color, fill: fill),
            const SizedBox(width: 6),
            Text(label, style: cairoStyle(12.5, weight: 600, color: color)),
          ]),
        ),
      ),
    );
  }
}

/// حوار تأكيد بنفس لغة الكروت (بدل AlertDialog الافتراضي).
Future<bool> _confirmDialog(BuildContext context,
    {required String title,
    required String message,
    required String confirmLabel}) async {
  final t = HomeTokens.of(context);
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: t.card,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: t.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: cairoStyle(16.5, weight: 700, color: t.ink)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: cairoStyle(13, color: t.muted, height: 1.6)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: HomeButton(
                    tk: t,
                    label: 'إلغاء',
                    onTap: () => Navigator.pop(ctx, false))),
            const SizedBox(width: 10),
            Expanded(
                child: HomeButton(
                    tk: t,
                    label: confirmLabel,
                    primary: true,
                    onTap: () => Navigator.pop(ctx, true))),
          ]),
        ]),
      ),
    ),
  );
  return r == true;
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
      final t = HomeTokens.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(_forumSnack(t, text, error: true));
    }
  }

  Widget _tile(Map<String, dynamic> c, {required bool isReply}) {
    final me = supabase.auth.currentUser?.id;
    final t = HomeTokens.of(context);
    final p = (c['profiles'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = displayName(p);
    final liked = _liked.contains(c['id'].toString());
    final likes = (c['like_count'] ?? 0) as int;
    final small = cairoStyle(12, weight: 700, color: t.muted);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Avatar(name: name, size: isReply ? 28 : 36),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
              decoration: BoxDecoration(
                  color: t.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.line)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: cairoStyle(13, weight: 700, color: t.ink)),
                    const SizedBox(height: 2),
                    Text(c['body']?.toString() ?? '',
                        style: cairoStyle(14, color: t.ink, height: 1.55)),
                  ]),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 6, left: 6),
              child: Row(children: [
                Text(timeAgo(c['created_at']?.toString()),
                    style: cairoStyle(11, color: t.muted)),
                const SizedBox(width: 14),
                GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggleLike(c),
                    child: Text(likes > 0 ? 'أعجبني · $likes' : 'أعجبني',
                        style: small.copyWith(
                            color: liked ? _heartRed : t.muted))),
                const SizedBox(width: 14),
                GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _startReply(c),
                    child: Text('رد', style: small)),
                if (c['author_id'] == me) ...[
                  const SizedBox(width: 14),
                  GestureDetector(
                      behavior: HitTestBehavior.opaque,
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
    final t = HomeTokens.of(context);
    final roots = _comments.where((c) => c['parent_id'] == null).toList();
    final replies = <String, List<Map<String, dynamic>>>{};
    for (final c in _comments) {
      final pid = c['parent_id']?.toString();
      if (pid != null) replies.putIfAbsent(pid, () => []).add(c);
    }
    return Padding(
      // يرفع حقل التعليق فوق الكيبورد بدل ما يختفي خلفه
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: math.min(screen * .72, screen - bottom - 140),
        child: Column(children: [
          Text('التعليقات (${_comments.length})',
              style: cairoStyle(16.5, weight: 700, color: t.ink)),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: t.gold))
                : roots.isEmpty
                    ? HomeEmpty(
                        tk: t,
                        icon: HomeIcons.forum,
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
                                    padding: const EdgeInsetsDirectional.only(
                                        start: 30),
                                    child: Container(
                                      decoration: BoxDecoration(
                                          border: BorderDirectional(
                                              start: BorderSide(
                                                  color: t.line, width: 2))),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: t.mint, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(
                    child: Text('رد على ${_replyTo!['reply_name']}',
                        style: cairoStyle(12, weight: 700, color: t.mintInk))),
                GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _replyTo = null),
                    child:
                        StyledIcon(ZikrIcons.close, size: 16, color: t.mintInk)),
              ]),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                minLines: 1,
                maxLines: 3,
                maxLength: 2000,
                cursorColor: t.gold,
                style: cairoStyle(14, color: t.ink, height: 1.5),
                buildCounter: (_,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                decoration: InputDecoration(
                  hintText: _replyTo == null ? 'اكتب تعليقًا...' : 'اكتب ردك...',
                  hintStyle: cairoStyle(14, color: t.muted),
                  filled: true,
                  fillColor: t.bg,
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: t.line)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: t.line)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide:
                          BorderSide(color: t.gold.withValues(alpha: .7))),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _sending ? null : _send,
              child: Opacity(
                opacity: _sending ? .5 : 1,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: t.mint,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.leaf)),
                  child: Center(
                      child:
                          StyledIcon(_Ic.send, size: 19, color: t.mintInk)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet();

  @override
  Widget build(BuildContext context) {
    final t = HomeTokens.of(context);
    const options = {
      'spam': 'محتوى مزعج أو ترويجي',
      'harassment': 'إساءة أو تنمر',
      'hate': 'خطاب كراهية',
      'misinformation': 'معلومة مضللة',
      'inappropriate': 'محتوى غير مناسب',
      'other': 'سبب آخر',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('لماذا تريد الإبلاغ؟',
            style: cairoStyle(16.5, weight: 700, color: t.ink)),
        const SizedBox(height: 6),
        for (final e in options.entries)
          HomeSheetRow(
              tk: t,
              icon: _Ic.flag,
              label: e.value,
              onTap: () => Navigator.pop(context, e.key)),
      ],
    );
  }
}

SnackBar _forumSnack(HomeTokens t, String message, {bool error = false}) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: t.card,
    elevation: 0,
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: error ? _heartRed : t.gold),
    ),
    content: Text(message, style: cairoStyle(13.5, weight: 600, color: t.ink)),
  );
}

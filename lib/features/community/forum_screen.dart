import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_config.dart';
import '../../widgets/app_ui.dart';
import 'auth_screen.dart';
import 'groups_screen.dart';
import 'account_screen.dart';
import 'notifications_screen.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});
  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  int _section = 0;
  bool _loading = true;
  bool _posting = false;
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

  Future<List<Map<String, dynamic>>> _fetchFeed() async {
    final rows = await supabase.from('posts').select('*, profiles!posts_author_id_fkey(username, full_name)').order('created_at', ascending: false).limit(60);
    final userId = supabase.auth.currentUser?.id;
    final liked = userId == null
        ? <String>{}
        : ((await supabase.from('post_likes').select('post_id').eq('user_id', userId)) as List)
            .map((e) => e['post_id'].toString()).toSet();
    return (rows as List).map((row) {
      final item = Map<String, dynamic>.from(row as Map);
      item['liked'] = liked.contains(item['id'].toString());
      return item;
    }).toList();
  }

  Future<void> _loadFeed() async {
    if (mounted) setState(() => _loading = true);
    try {
      final posts = await _fetchFeed();
      if (mounted) setState(() { _posts = posts; _loading = false; });
    } catch (_) {
      if (mounted) { setState(() => _loading = false); _toast('تعذر تحميل المنشورات الآن.', error: true); }
    }
  }

  Future<bool> _requireAuth({bool signUp = false}) async {
    if (supabase.auth.currentUser != null) return true;
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CommunityAuthScreen(signUp: signUp)));
    if (result == true && mounted) await _loadFeed();
    return result == true;
  }

  Future<void> _createPost() async {
    if (!await _requireAuth()) return;
    final body = _composer.text.trim();
    if (body.isEmpty) { _toast('اكتب شيئًا قبل النشر.'); return; }
    setState(() => _posting = true);
    try {
      await supabase.from('posts').insert({'author_id': supabase.auth.currentUser!.id, 'body': body, 'visibility': 'public'});
      _composer.clear();
      await _loadFeed();
      if (mounted) _toast('تم نشر كلامك في المنتدى.');
    } on PostgrestException catch (e) { if (mounted) _toast(e.message, error: true); }
    finally { if (mounted) setState(() => _posting = false); }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    if (!await _requireAuth()) return;
    final id = post['id'].toString();
    final userId = supabase.auth.currentUser!.id;
    try {
      if (post['liked'] == true) {
        await supabase.from('post_likes').delete().match({'post_id': id, 'user_id': userId});
      } else {
        await supabase.from('post_likes').insert({'post_id': id, 'user_id': userId});
      }
      await _loadFeed();
    } catch (_) { if (mounted) _toast('تعذر تحديث التفاعل.', error: true); }
  }

  Future<void> _share(Map<String, dynamic> post) async {
    if (!await _requireAuth()) return;
    try {
      await supabase.from('post_shares').insert({'post_id': post['id'], 'user_id': supabase.auth.currentUser!.id});
      if (mounted) _toast('تمت مشاركة المنشور في ملفك.');
      await _loadFeed();
    } catch (_) { if (mounted) _toast('تعذرت المشاركة الآن.', error: true); }
  }

  Future<void> _report(Map<String, dynamic> post) async {
    if (!await _requireAuth()) return;
    final reason = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (context) => _ReportSheet());
    if (reason == null) return;
    try {
      await supabase.from('reports').insert({'reporter_id': supabase.auth.currentUser!.id, 'post_id': post['id'], 'reason': reason});
      if (mounted) _toast('وصل بلاغك وسيراجعه فريق الإشراف.');
    } catch (_) { if (mounted) _toast('تعذر إرسال البلاغ.', error: true); }
  }

  Future<void> _openComments(Map<String, dynamic> post) async {
    if (supabase.auth.currentUser == null) {
      if (!await _requireAuth()) return;
    }
    await showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _CommentsSheet(post: post));
    _loadFeed();
  }

  void _toast(String message, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? Theme.of(context).colorScheme.error : null));

  Future<void> _openAccount() async {
    if (!await _requireAuth()) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CommunityAccountScreen()));
    if (mounted) setState(() {});
    _loadFeed();
  }

  Future<void> _openNotifications() async {
    if (!await _requireAuth()) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CommunityNotificationsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadFeed,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _ForumHeader(user: user, onProfile: () { _openAccount(); }, onNotifications: () { _openNotifications(); }, onRefresh: () { _loadFeed(); })),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: SegmentedButton<int>(segments: const [ButtonSegment(value: 0, label: Text('آخر المنشورات'), icon: Icon(Icons.dynamic_feed_outlined)), ButtonSegment(value: 1, label: Text('الجروبات'), icon: Icon(Icons.groups_outlined))], selected: {_section}, onSelectionChanged: (s) => setState(() => _section = s.first)))),
          if (_section == 1)
            const SliverFillRemaining(child: GroupsScreen())
          else ...[
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 10), child: _Composer(controller: _composer, onPost: _createPost, loading: _posting, signedIn: user != null, onSignIn: () => _requireAuth(signUp: true)))),
            if (_loading) const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_posts.isEmpty) const SliverFillRemaining(child: AppEmptyState(icon: Icons.forum_outlined, title: 'المنتدى ينتظر كلمتك', message: 'كن أول من يشارك فكرة طيبة أو فائدة نافعة.'))
            else SliverPadding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), sliver: SliverList.builder(itemCount: _posts.length, itemBuilder: (_, i) => _PostCard(post: _posts[i], onLike: () => _toggleLike(_posts[i]), onComment: () => _openComments(_posts[i]), onShare: () => _share(_posts[i]), onReport: () => _report(_posts[i])))),
          ],
        ]),
      ),
    );
  }
}

class _ForumHeader extends StatelessWidget {
  final User? user;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;
  final VoidCallback onRefresh;
  const _ForumHeader({required this.user, required this.onProfile, required this.onNotifications, required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.forum_rounded, color: scheme.primary, size: 27)),
      const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('المنتدى', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('كلمة طيبة، أثر جميل', style: TextStyle(fontSize: 13))])),
      IconButton(onPressed: onNotifications, icon: const Icon(Icons.notifications_none_rounded)),
      IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded)),
      IconButton(onPressed: onProfile, icon: Icon(user == null ? Icons.login_rounded : Icons.account_circle_outlined)),
    ]);
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onPost;
  final VoidCallback onSignIn;
  final bool loading;
  final bool signedIn;
  const _Composer({required this.controller, required this.onPost, required this.loading, required this.signedIn, required this.onSignIn});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(padding: const EdgeInsets.all(16), pattern: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [AppIconBadge(icon: signedIn ? Icons.edit_note_rounded : Icons.lock_outline_rounded, size: 42), const SizedBox(width: 10), Expanded(child: Text(signedIn ? 'شارك ما ينفع الناس' : 'سجّل دخولك لتكتب في المنتدى', style: const TextStyle(fontWeight: FontWeight.w800)))]),
      const SizedBox(height: 12),
      TextField(controller: controller, minLines: 2, maxLines: 5, enabled: signedIn, decoration: InputDecoration(hintText: signedIn ? 'اكتب منشورًا نصيًا...' : 'المنشورات النصية فقط، بلا تشتيت', filled: true, fillColor: scheme.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none))),
      const SizedBox(height: 10),
      Align(alignment: AlignmentDirectional.centerEnd, child: FilledButton.icon(onPressed: signedIn ? (loading ? null : onPost) : onSignIn, icon: Icon(signedIn ? Icons.send_rounded : Icons.login_rounded), label: Text(signedIn ? (loading ? 'ينشر...' : 'نشر') : 'دخول'))),
    ]));
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onReport;
  const _PostCard({required this.post, required this.onLike, required this.onComment, required this.onShare, required this.onReport});
  String _time() { final date = DateTime.tryParse(post['created_at']?.toString() ?? '')?.toLocal(); if (date == null) return ''; final diff = DateTime.now().difference(date); if (diff.inMinutes < 1) return 'الآن'; if (diff.inHours < 1) return 'منذ ${diff.inMinutes} د'; if (diff.inDays < 1) return 'منذ ${diff.inHours} س'; return 'منذ ${diff.inDays} يوم'; }
  @override
  Widget build(BuildContext context) {
    final profile = (post['profiles'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = (profile['full_name']?.toString().trim().isNotEmpty == true) ? profile['full_name'].toString() : '@${profile['username'] ?? 'عضو'}';
    final scheme = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(top: 12), child: AppCard(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [CircleAvatar(radius: 21, backgroundColor: scheme.primaryContainer, child: Text(name.isEmpty ? 'ذ' : name.substring(0, 1), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w800)), Text('@${profile['username'] ?? 'member'} · ${_time()}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))])), PopupMenuButton<String>(onSelected: (v) { if (v == 'report') onReport(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('إبلاغ عن المنشور')))])]),
      const SizedBox(height: 14),
      Text(post['body']?.toString() ?? '', style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65)),
      const SizedBox(height: 14),
      Row(children: [Text('${post['like_count'] ?? 0} إعجاب', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)), const SizedBox(width: 12), Text('${post['comment_count'] ?? 0} تعليق', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)), const SizedBox(width: 12), Text('${post['share_count'] ?? 0} مشاركة', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))]),
      const Divider(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_Action(icon: post['liked'] == true ? Icons.favorite : Icons.favorite_border, label: 'أعجبني', active: post['liked'] == true, onTap: onLike), _Action(icon: Icons.mode_comment_outlined, label: 'تعليق', onTap: onComment), _Action(icon: Icons.repeat_rounded, label: 'مشاركة', onTap: onShare)]),
    ])));
  }
}

class _Action extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final bool active;
  const _Action({required this.icon, required this.label, required this.onTap, this.active = false});
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), child: Row(children: [Icon(icon, size: 20, color: active ? Theme.of(context).colorScheme.error : null), const SizedBox(width: 5), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Theme.of(context).colorScheme.error : null))])));
}

class _CommentsSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  const _CommentsSheet({required this.post});
  @override State<_CommentsSheet> createState() => _CommentsSheetState();
}
class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  Future<void> _load() async { try { final data = await supabase.from('comments').select('*, profiles!comments_author_id_fkey(username, full_name)').eq('post_id', widget.post['id']).order('created_at'); if (mounted) setState(() { _comments = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(); _loading = false; }); } catch (_) { if (mounted) setState(() => _loading = false); } }
  Future<void> _send() async { final text = _controller.text.trim(); if (text.isEmpty) return; try { await supabase.from('comments').insert({'post_id': widget.post['id'], 'author_id': supabase.auth.currentUser!.id, 'body': text}); _controller.clear(); _load(); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر نشر التعليق.'))); } }
  @override Widget build(BuildContext context) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .72, child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Column(children: [const Text('التعليقات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 12), Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _comments.isEmpty ? const AppEmptyState(icon: Icons.chat_bubble_outline, title: 'لا توجد تعليقات بعد', message: 'ابدأ نقاشًا نافعًا ومحترمًا.') : ListView.builder(itemCount: _comments.length, itemBuilder: (_, i) { final c = _comments[i]; final p = (c['profiles'] as Map?)?.cast<String, dynamic>() ?? {}; return ListTile(leading: const CircleAvatar(child: Icon(Icons.person_outline)), title: Text(p['full_name']?.toString().isNotEmpty == true ? p['full_name'].toString() : '@${p['username'] ?? 'عضو'}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(c['body']?.toString() ?? ''); })), Row(children: [Expanded(child: TextField(controller: _controller, minLines: 1, maxLines: 3, decoration: const InputDecoration(hintText: 'اكتب تعليقًا...'))), const SizedBox(width: 8), IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded))])]))));
}

class _ReportSheet extends StatelessWidget {
  @override Widget build(BuildContext context) { const options = {'spam': 'محتوى مزعج أو ترويجي', 'harassment': 'إساءة أو تنمر', 'hate': 'خطاب كراهية', 'misinformation': 'معلومة مضللة', 'inappropriate': 'محتوى غير مناسب', 'other': 'سبب آخر'}; return SafeArea(child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 22), children: [const Text('لماذا تريد الإبلاغ؟', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), const SizedBox(height: 8), ...options.entries.map((e) => ListTile(leading: const Icon(Icons.flag_outlined), title: Text(e.value), onTap: () => Navigator.pop(context, e.key)))])); }
}

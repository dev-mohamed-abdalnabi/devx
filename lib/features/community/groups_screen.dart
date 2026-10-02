import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_config.dart';
import '../../widgets/app_ui.dart';
import 'community_utils.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _groups = [];

  /// group_id -> {role, status} لعضويتي أنا
  Map<String, Map<String, dynamic>> _mine = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await supabase
          .from('groups')
          .select('*, profiles!groups_owner_id_fkey(username, full_name)')
          .order('created_at', ascending: false);
      final userId = supabase.auth.currentUser?.id;
      final mine = <String, Map<String, dynamic>>{};
      if (userId != null) {
        final rows = await supabase
            .from('group_members')
            .select('group_id, role, status')
            .eq('user_id', userId);
        for (final r in rows as List) {
          mine[r['group_id'].toString()] = Map<String, dynamic>.from(r as Map);
        }
      }
      if (!mounted) return;
      setState(() {
        _groups = (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _mine = mine;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _requireUser() {
    if (supabase.auth.currentUser != null) return true;
    _message('سجّل الدخول أولًا من أعلى المنتدى.');
    return false;
  }

  Future<void> _create() async {
    if (!_requireUser()) return;
    final result = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => const _CreateGroupDialog());
    if (result == null) return;
    try {
      // المالك يُضاف تلقائيًا كعضو بواسطة trigger في قاعدة البيانات،
      // لذلك لا نُدخل صف العضوية يدويًا (كان يسبب خطأ تكرار رغم نجاح الإنشاء).
      await supabase.from('groups').insert({
        'owner_id': supabase.auth.currentUser!.id,
        'name': result['name'],
        'description': result['description'],
        'is_private': result['private'] == true,
      });
      await _load();
      _message('تم إنشاء الجروب.');
    } on PostgrestException catch (e) {
      _message(e.code == pgUniqueViolation
          ? 'لديك جروب بنفس الاسم.'
          : 'تعذر إنشاء الجروب.');
    } catch (_) {
      _message('تعذر إنشاء الجروب.');
    }
  }

  Future<void> _join(Map<String, dynamic> group) async {
    if (!_requireUser()) return;
    final id = group['id'].toString();
    if (!_busy.add(id)) return;
    setState(() {});
    try {
      // الدور والحالة يحددهما الخادم (عضو / قيد المراجعة للجروب الخاص).
      await supabase.from('group_members').insert({
        'group_id': id,
        'user_id': supabase.auth.currentUser!.id,
      });
      _message(group['is_private'] == true
          ? 'تم إرسال طلب الانضمام.'
          : 'انضممت إلى الجروب.');
      await _load();
    } on PostgrestException catch (e) {
      _message(e.code == pgUniqueViolation
          ? 'أنت عضو بالفعل أو طلبك قيد المراجعة.'
          : 'تعذر الانضمام.');
    } catch (_) {
      _message('تعذر الانضمام.');
    } finally {
      _busy.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _leave(Map<String, dynamic> group, {required bool pending}) async {
    final id = group['id'].toString();
    if (!_busy.add(id)) return;
    setState(() {});
    try {
      await supabase.from('group_members').delete().match({
        'group_id': id,
        'user_id': supabase.auth.currentUser!.id,
      });
      _message(pending ? 'تم إلغاء الطلب.' : 'غادرت الجروب.');
      await _load();
    } catch (_) {
      _message('تعذر تنفيذ العملية.');
    } finally {
      _busy.remove(id);
      if (mounted) setState(() {});
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _action(Map<String, dynamic> g) {
    final id = g['id'].toString();
    final membership = _mine[id];
    final userId = supabase.auth.currentUser?.id;
    if (_busy.contains(id)) {
      return const SizedBox(
          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (g['owner_id'] == userId || membership?['role'] == 'owner') {
      return const Chip(label: Text('جروبك'), visualDensity: VisualDensity.compact);
    }
    switch (membership?['status']) {
      case 'active':
        return OutlinedButton(
            onPressed: () => _leave(g, pending: false), child: const Text('مغادرة'));
      case 'pending':
        return OutlinedButton(
            onPressed: () => _leave(g, pending: true),
            child: const Text('إلغاء الطلب'));
      case 'blocked':
        return const Chip(label: Text('محظور'), visualDensity: VisualDensity.compact);
      default:
        return FilledButton.tonal(
            onPressed: () => _join(g),
            child: Text(g['is_private'] == true ? 'طلب انضمام' : 'انضمام'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Row(children: [
          const Expanded(
              child: Text('جروبات مفيدة',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
          FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('جروب جديد')),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _groups.isEmpty
                    ? ListView(children: const [
                        AppEmptyState(
                            icon: Icons.groups_outlined,
                            title: 'لا توجد جروبات بعد',
                            message: 'أنشئ أول مساحة تجمع أصحاب الاهتمام الواحد.')
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        itemCount: _groups.length,
                        itemBuilder: (_, i) {
                          final g = _groups[i];
                          final p =
                              (g['profiles'] as Map?)?.cast<String, dynamic>() ?? {};
                          final desc = g['description']?.toString() ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(children: [
                                AppIconBadge(
                                    icon: g['is_private'] == true
                                        ? Icons.lock_outline
                                        : Icons.groups_rounded,
                                    size: 48),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(g['name']?.toString() ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16)),
                                        if (desc.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(desc,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis),
                                        ],
                                        const SizedBox(height: 5),
                                        Text(
                                            '${g['member_count'] ?? 0} عضو · بواسطة ${displayName(p)}',
                                            style:
                                                Theme.of(context).textTheme.bodySmall),
                                      ]),
                                ),
                                const SizedBox(width: 8),
                                _action(g),
                              ]),
                            ),
                          );
                        }),
              ),
      ),
    ]);
  }
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();
  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _private = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'اسم الجروب حرفان على الأقل.');
      return;
    }
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'private': _private,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('جروب جديد'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _name,
                maxLength: 80,
                decoration:
                    InputDecoration(labelText: 'اسم الجروب', errorText: _error)),
            const SizedBox(height: 8),
            TextField(
                controller: _desc,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'وصف مختصر')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('جروب خاص'),
              subtitle: const Text('الانضمام بموافقتك'),
              value: _private,
              onChanged: (v) => setState(() => _private = v),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: _submit, child: const Text('إنشاء')),
        ],
      );
}

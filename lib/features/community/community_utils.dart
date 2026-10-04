// دوال مشتركة لشاشات المجتمع (المنتدى، الجروبات، الإشعارات).

String timeAgo(String? iso) {
  final date = DateTime.tryParse(iso ?? '')?.toLocal();
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inHours < 1) return 'منذ ${diff.inMinutes} د';
  if (diff.inDays < 1) return 'منذ ${diff.inHours} س';
  if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
  if (diff.inDays < 365) return 'منذ ${diff.inDays ~/ 30} شهر';
  return 'منذ ${diff.inDays ~/ 365} سنة';
}

String displayName(Map? profile, {String fallback = 'عضو'}) {
  final full = profile?['full_name']?.toString().trim() ?? '';
  if (full.isNotEmpty) return full;
  final user = profile?['username']?.toString().trim() ?? '';
  return user.isNotEmpty ? '@$user' : fallback;
}

String initialOf(String name) {
  final t = name.replaceFirst('@', '').trim();
  if (t.isEmpty) return 'ذ';
  return String.fromCharCode(t.runes.first);
}

/// رمز خطأ Postgres للقيد الفريد (تكرار لايك/مشاركة/بلاغ).
const pgUniqueViolation = '23505';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_config.dart';

class CommunityAuthScreen extends StatefulWidget {
  final bool signUp;
  const CommunityAuthScreen({super.key, this.signUp = false});

  @override
  State<CommunityAuthScreen> createState() => _CommunityAuthScreenState();
}

class _CommunityAuthScreenState extends State<CommunityAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.signUp;
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isSignUp) {
        final response = await supabase.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {
            'full_name': _name.text.trim(),
            'username': _username.text.trim().toLowerCase(),
          },
        );
        if (!mounted) return;
        if (response.session == null) {
          _message('تم إنشاء الحساب. افحص بريدك الإلكتروني لتأكيد الحساب.');
        } else {
          Navigator.of(context).pop(true);
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (mounted) Navigator.of(context).pop(true);
      }
    } on AuthException catch (error) {
      if (mounted) _message(_arabicAuthError(error.message), error: true);
    } catch (_) {
      if (mounted) _message('تعذر إكمال العملية الآن، حاول مرة أخرى.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _arabicAuthError(String message) {
    if (message.toLowerCase().contains('invalid login')) return 'البريد أو كلمة المرور غير صحيحة.';
    if (message.toLowerCase().contains('already registered')) return 'هذا البريد مسجل بالفعل.';
    if (message.toLowerCase().contains('password')) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.';
    return message;
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'اكتب $label' : null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'إنشاء حساب' : 'تسجيل الدخول')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(children: [
                Icon(Icons.forum_rounded, size: 38, color: scheme.primary),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('مجتمع ذكر', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('مساحة محترمة للكلمة الطيبة والتعاون.', style: text.bodyMedium),
                ])),
              ]),
            ),
            const SizedBox(height: 28),
            Form(
              key: _formKey,
              child: Column(children: [
                if (_isSignUp) ...[
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'الاسم الظاهر', prefixIcon: Icon(Icons.badge_outlined)),
                    validator: (v) => _required(v, 'اسمك'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _username,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.alternate_email_rounded)),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.length < 3) return 'اسم المستخدم 3 أحرف على الأقل';
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) return 'استخدم حروفًا إنجليزية وأرقامًا فقط';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => _required(v, 'البريد الإلكتروني'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
                  ),
                  validator: (v) => (v ?? '').length < 6 ? 'كلمة المرور 6 أحرف على الأقل' : null,
                ),
              ]),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_isSignUp ? Icons.person_add_alt_1_rounded : Icons.login_rounded),
                label: Text(_loading ? 'لحظة من فضلك...' : (_isSignUp ? 'إنشاء الحساب' : 'دخول المنتدى')),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _loading ? null : () => setState(() => _isSignUp = !_isSignUp),
              child: Text(_isSignUp ? 'لديك حساب؟ سجل الدخول' : 'ليس لديك حساب؟ أنشئ حسابًا'),
            ),
            const SizedBox(height: 18),
            Text('بإنشاء الحساب توافق على احترام الآخرين وعدم نشر الإساءة أو التضليل.', textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

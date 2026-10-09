import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/home_tokens.dart';
import '../core/text_utils.dart';
import '../providers/azkar_provider.dart';
import '../features/home/home_art.dart';
import '../features/reminders/reminders_screen.dart';
import 'about_screen.dart';
import 'privacy_screen.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // لا نفحص الخادم عند تشغيل التطبيق؛ الفحص مقصود فقط عند دخول الإعدادات.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.checkAndShow(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AzkarProvider>();
    final tk = HomeTokens.of(context);
    final mq = MediaQuery.of(context);

    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
            child: Text('خصّص تجربة القراءة والذكر كما تحب',
                style: cairoStyle(13.5, color: tk.muted)),
          ),
          _Heading(tk: tk, text: 'المظهر والقراءة'),
          _Group(
            tk: tk,
            children: [
              _ThemeRow(tk: tk, provider: provider),
              _SwitchRow(
                tk: tk,
                icon: Icons.menu_book_rounded,
                title: 'إظهار مصدر الذكر',
                subtitle: 'عرض حصن المسلم ورقم الذكر المرجعي',
                value: provider.showSources,
                onChanged: (_) => provider.toggleSources(),
              ),
              _FontRow(tk: tk, provider: provider),
            ],
          ),
          const SizedBox(height: 22),
          _Heading(tk: tk, text: 'التنبيهات'),
          _NavRow(
            tk: tk,
            icon: Icons.notifications_active_rounded,
            title: 'التذكيرات',
            subtitle: 'الأذكار والقرآن والتحديات وتذكيرات مخصصة',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RemindersScreen())),
          ),
          const SizedBox(height: 22),
          _Heading(tk: tk, text: 'حول التطبيق'),
          _AboutCard(
            tk: tk,
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
          const SizedBox(height: 10),
          _NavRow(
            tk: tk,
            icon: Icons.shield_outlined,
            title: 'الخصوصية',
            subtitle: 'الموقع والإشعارات والبيانات المحلية',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final HomeTokens tk;
  final String text;
  const _Heading({required this.tk, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                  color: tk.gold, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(text, style: cairoStyle(15, weight: 700, color: tk.ink)),
          ],
        ),
      );
}

/// مجموعة صفوف داخل كارت واحد مع فواصل رفيعة.
class _Group extends StatelessWidget {
  final HomeTokens tk;
  final List<Widget> children;
  const _Group({required this.tk, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tk.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tk.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: tk.line),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _IconDot extends StatelessWidget {
  final HomeTokens tk;
  final IconData icon;
  const _IconDot({required this.tk, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: tk.mint, shape: BoxShape.circle),
        child: Icon(icon, size: 21, color: tk.mintInk),
      );
}

class _SwitchRow extends StatelessWidget {
  final HomeTokens tk;
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.tk,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _IconDot(tk: tk, icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: cairoStyle(14.5, weight: 700, color: tk.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: cairoStyle(12, color: tk.muted, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: tk.leaf,
              activeThumbColor: Colors.white,
              inactiveTrackColor: tk.line,
              inactiveThumbColor: tk.muted,
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  final HomeTokens tk;
  final AzkarProvider provider;
  const _ThemeRow({required this.tk, required this.provider});

  @override
  Widget build(BuildContext context) {
    const opts = [
      (ThemeMode.system, 'تلقائي', Icons.brightness_auto_rounded),
      (ThemeMode.light, 'فاتح', Icons.light_mode_rounded),
      (ThemeMode.dark, 'داكن', Icons.dark_mode_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconDot(tk: tk, icon: Icons.contrast_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المظهر',
                        style: cairoStyle(14.5, weight: 700, color: tk.ink)),
                    const SizedBox(height: 2),
                    Text('التلقائي يتبع وضع الجهاز (فاتح أو داكن)',
                        style: cairoStyle(12, color: tk.muted, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: tk.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tk.line),
            ),
            child: Row(
              children: [
                for (final o in opts)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => provider.setThemeMode(o.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: provider.themeMode == o.$1
                              ? tk.mint
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: provider.themeMode == o.$1
                                  ? tk.gold.withValues(alpha: .55)
                                  : Colors.transparent),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(o.$3,
                                size: 17,
                                color: provider.themeMode == o.$1
                                    ? tk.mintInk
                                    : tk.muted),
                            const SizedBox(width: 6),
                            Text(o.$2,
                                style: cairoStyle(13,
                                    weight: 700,
                                    color: provider.themeMode == o.$1
                                        ? tk.mintInk
                                        : tk.muted)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FontRow extends StatelessWidget {
  final HomeTokens tk;
  final AzkarProvider provider;
  const _FontRow({required this.tk, required this.provider});

  @override
  Widget build(BuildContext context) {
    final pct = (provider.fontScale * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconDot(tk: tk, icon: Icons.text_fields_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text('حجم خط الأذكار',
                    style: cairoStyle(14.5, weight: 700, color: tk.ink)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tk.mint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tk.gold.withValues(alpha: .5)),
                ),
                child: Text('${toArabicDigits(pct)}٪',
                    style: cairoStyle(12.5, weight: 700, color: tk.mintInk)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // معاينة حيّة لحجم الخط.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: tk.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tk.line),
            ),
            child: Text(
              'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
              textAlign: TextAlign.center,
              style: amiriStyle(20 * provider.fontScale,
                  color: tk.ink, height: 1.8),
            ),
          ),
          Row(
            children: [
              Text('أ', style: cairoStyle(13, weight: 600, color: tk.muted)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 5,
                    activeTrackColor: tk.leaf,
                    inactiveTrackColor: tk.line,
                    thumbColor: tk.gold,
                    overlayColor: tk.gold.withValues(alpha: .16),
                    activeTickMarkColor: Colors.transparent,
                    inactiveTickMarkColor: Colors.transparent,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: provider.fontScale,
                    min: 0.8,
                    max: 1.6,
                    divisions: 8,
                    onChanged: provider.setFontScale,
                  ),
                ),
              ),
              Text('أ', style: cairoStyle(22, weight: 600, color: tk.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final HomeTokens tk;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _NavRow({
    required this.tk,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      builder: (context, pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tk.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: pressed ? tk.gold : tk.line),
        ),
        child: Row(
          children: [
            _IconDot(tk: tk, icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: cairoStyle(14.5, weight: 700, color: tk.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: cairoStyle(12, color: tk.muted, height: 1.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: tk.gold, size: 26),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final HomeTokens tk;
  final VoidCallback onTap;
  const _AboutCard({required this.tk, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      builder: (context, pressed) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tk.mint,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: tk.gold.withValues(alpha: pressed ? 1 : .55)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset('assets/brand/app_icon.png',
                  width: 52, height: 52),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('عن ذِكر',
                      style: cairoStyle(16, weight: 700, color: tk.mintInk)),
                  const SizedBox(height: 2),
                  Text('أذكار وقرآن ومواقيت صلاة ومجتمع',
                      style: cairoStyle(12,
                          color: tk.mintInk.withValues(alpha: .75),
                          height: 1.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: tk.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('1.3.0',
                  style: cairoStyle(11.5, weight: 700, color: tk.gold)),
            ),
            Icon(Icons.chevron_left_rounded, color: tk.gold, size: 24),
          ],
        ),
      ),
    );
  }
}

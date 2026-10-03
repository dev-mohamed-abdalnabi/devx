import 'package:flutter/material.dart';
import '../features/home/home_screen.dart';
import '../features/more/more_screen.dart';
import '../features/community/forum_screen.dart';
import '../features/quran/quran_home_screen.dart';
import '../features/home/home_svg.dart';

class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  void _go(int i) => setState(() => _index = i);
  @override Widget build(BuildContext context) {
    final pages = <Widget>[HomeDashboard(onSwitchTab: _go), const QuranHomeScreen(), const ForumScreen(), const MoreScreen()];
    return Scaffold(body: IndexedStack(index: _index, children: pages), bottomNavigationBar: Container(
      height: 62 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: Color(0xFFF7F5EE), border: Border(top: BorderSide(color: Color(0xFFE7E1CE)))),
      child: Row(children: [
        _NavItem(icon: 'home', label: 'الرئيسية', selected: _index == 0, onTap: () => _go(0)),
        _NavItem(icon: 'book', label: 'القرآن', selected: _index == 1, onTap: () => _go(1)),
        _NavItem(icon: 'chat', label: 'المنتدى', selected: _index == 2, onTap: () => _go(2)),
        _NavItem(icon: 'more', label: 'المزيد', selected: _index == 3, onTap: () => _go(3)),
      ]),
    ));
  }
}
class _NavItem extends StatelessWidget { final String icon, label; final bool selected; final VoidCallback onTap; const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap}); @override Widget build(BuildContext context) => Expanded(child: InkWell(onTap: onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [LineIcon(icon == 'home' ? LineIcon.home : icon == 'book' ? LineIcon.book : icon == 'chat' ? LineIcon.chat : LineIcon.more, size: 21, color: selected ? const Color(0xFFB8923A) : const Color(0xFF7B8270)), const SizedBox(height: 3), Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: selected ? const Color(0xFF1F2A1F) : const Color(0xFF7B8270))) ]))); }
class _NavPainter extends CustomPainter { final String icon; final Color color; _NavPainter(this.icon, this.color); @override void paint(Canvas c, Size s) { final p = Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=1.7..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round; c.scale(s.width/24,s.height/24); final q=Path(); if(icon=='home'){q..moveTo(4,11)..lineTo(12,4)..lineTo(20,11)..lineTo(20,20)..lineTo(15,20)..lineTo(15,14)..lineTo(9,14)..lineTo(9,20)..lineTo(4,20)..close();} else if(icon=='book'){q..moveTo(3,5)..cubicTo(6,4,9,4,12,6)..cubicTo(15,4,18,4,21,5)..lineTo(21,18)..cubicTo(18,17,15,17,12,19)..cubicTo(9,17,6,17,3,18)..close()..moveTo(12,6)..lineTo(12,19);} else if(icon=='chat'){q..moveTo(20,12)..cubicTo(20,17,16,20,12,20)..cubicTo(10,20,8,19,7,19)..lineTo(4,20)..lineTo(5,16)..cubicTo(2,11,6,5,12,4)..cubicTo(17,4,20,7,20,12);} else {for(final r in [const Rect.fromLTWH(4,4,6.5,6.5),const Rect.fromLTWH(13.5,4,6.5,6.5),const Rect.fromLTWH(4,13.5,6.5,6.5),const Rect.fromLTWH(13.5,13.5,6.5,6.5)]) c.drawRRect(RRect.fromRectAndRadius(r,const Radius.circular(1.5)),p); return;} c.drawPath(q,p);} @override bool shouldRepaint(covariant _NavPainter old)=>old.icon!=icon||old.color!=color; }

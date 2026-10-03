import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LineIcon extends StatelessWidget {
  static const clock = 'clock', hourglass = 'hourglass', hand = 'hand', book = 'book', headphones = 'headphones', sparkle = 'sparkle', heart = 'heart', trophy = 'trophy', moon = 'moon', home = 'home', chat = 'chat', more = 'more';
  final String icon;
  final double size;
  final Color? color;
  const LineIcon(this.icon, {this.size = 24, this.color, super.key});

  static const _paths = <String, String>{
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    hourglass: '<path d="M6 3h12M6 21h12M7 3c0 5 5 6 5 9s-5 4-5 9M17 3c0 5-5 6-5 9s5 4 5 9"/>',
    hand: '<path d="M8 11V6a1.5 1.5 0 0 1 3 0v4M11 10V4.5a1.5 1.5 0 0 1 3 0V10M14 10V6a1.5 1.5 0 0 1 3 0v6c0 4-2 7-6 7-3 0-4-2-6-5l-1-2a1.5 1.5 0 0 1 2.5-1.5L8 13"/>',
    book: '<path d="M3 5c3-1 6-1 9 1 3-2 6-2 9-1v13c-3-1-6-1-9 1-3-2-6-2-9-1zM12 6v13"/>',
    headphones: '<path d="M4 15v-3a8 8 0 0 1 16 0v3M4 15a2 2 0 0 1 2-2h1v6H6a2 2 0 0 1-2-2zM20 15a2 2 0 0 0-2-2h-1v6h1a2 2 0 0 0 2-2z"/>',
    sparkle: '<path d="M9 4l1.8 4.2L15 10l-4.2 1.8L9 16l-1.8-4.2L3 10l4.2-1.8zM17 14l.9 2.1L20 17l-2.1.9L17 20l-.9-2.1L14 17l2.1-.9z"/>',
    heart: '<path d="M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.5-7 10-7 10z"/>',
    trophy: '<path d="M8 4h8v4a4 4 0 0 1-8 0zM8 6H4v1a3 3 0 0 0 4 3M16 6h4v1a3 3 0 0 1-4 3M12 12v4M8 20h8"/>',
    moon: '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>',
    home: '<path d="M4 11l8-7 8 7v9h-5v-6H9v6H4z"/>',
    chat: '<path d="M20 12a8 8 0 0 1-11.5 7.2L4 20l1-4.2A8 8 0 1 1 20 12z"/>',
    more: '<rect x="4" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="1.5"/><rect x="4" y="13.5" width="6.5" height="6.5" rx="1.5"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="1.5"/>';
  };

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${_paths[icon]}</g></svg>',
    width: size, height: size, colorFilter: ColorFilter.mode(color ?? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD4AE5A) : const Color(0xFFB8923A)), BlendMode.srcIn),
  );
}

class MosqueSvg extends StatelessWidget {
  const MosqueSvg({super.key});
  @override
  Widget build(BuildContext context) => SvgPicture.string('''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 150 110"><g fill="#2F5A2A" opacity=".3"><rect x="0" y="100" width="150" height="10"/><path d="M38 72h64v28H38z"/><path d="M40 72a30 30 0 0 1 60 0z"/><path d="M24 100V90a7 7 0 0 1 14 0v10zM102 100V90a7 7 0 0 1 14 0v10z"/><rect x="8" y="54" width="12" height="46"/><rect x="5" y="52" width="18" height="3"/><rect x="10" y="42" width="8" height="10"/><path d="M9 42l5-14 5 14z"/><rect x="130" y="54" width="12" height="46"/><rect x="127" y="52" width="18" height="3"/><rect x="132" y="42" width="8" height="10"/><path d="M131 42l5-14 5 14z"/></g><g fill="#B8923A"><rect x="69.5" y="27" width="1" height="16"/><circle cx="70" cy="19" r="7"/><circle cx="72.5" cy="18" r="5.5" fill="#E3EFD8"/><circle cx="14" cy="26" r="1.6"/><circle cx="136" cy="26" r="1.6"/><circle cx="100" cy="12" r="1.2"/><circle cx="40" cy="14" r="1.2"/><circle cx="118" cy="30" r="1"/></g><g fill="none" stroke="#E3EFD8" stroke-width="1.2" stroke-linecap="round"><path d="M70 43v28M56 49q-4 11-4 22M84 49q4 11 4 22"/><path d="M40 72h60"/></g><g fill="#E3EFD8"><path d="M46 94v-8a4 4 0 0 1 8 0v8zM86 94v-8a4 4 0 0 1 8 0v8z"/><path d="M64 100V86a6 6 0 0 1 12 0v14z"/><rect x="13" y="64" width="2" height="8" rx="1"/><rect x="13" y="80" width="2" height="8" rx="1"/><rect x="135" y="64" width="2" height="8" rx="1"/><rect x="135" y="80" width="2" height="8" rx="1"/><path d="M28 100v-6a3 3 0 0 1 6 0v6zM106 100v-6a3 3 0 0 1 6 0v6z"/></g></svg>''', width: 190, height: 140);
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

// Sizes in logical pixels, scaled from the design mockup.
const double _kBarHeight = 64; // the bar itself, without the halo bump
const double _kOverhang = 11; // how far the halo bump rises above the bar
const double _kHaloRadius = 31; // round bump around the middle button
const double _kHaloCenterY = 20; // bump center, measured down from bar top
const double _kFillet = 9; // smooth curve where the bar meets the bump
const double _kCorner = 16; // rounded corners on all four bar corners
const double _kButtonSize = 52; // the blue middle button

/// Colors of the bar. [light] matches the mockup; [dark] is the same layout
/// with the colors swapped. Nothing else about the bar changes.
class PillNavStyle {
  const PillNavStyle({
    required this.bar,
    required this.glow,
    required this.accent,
    required this.button,
    required this.onButton,
    required this.icon,
    required this.label,
    required this.shadow,
  });

  final Color bar; // bar background
  final Color glow; // soft blue glow around the middle button
  final Color accent; // selected tab (icon + label)
  final Color button; // middle button fill
  final Color onButton; // middle button icon
  final Color icon; // unselected icon
  final Color label; // unselected label
  final Color shadow; // bar shadow

  static const light = PillNavStyle(
    bar: Color(0xFFF3F6FD),
    glow: Color(0xFF3388FD),
    accent: Color(0xFF2D80FB),
    button: Color(0xFF358BFD),
    onButton: Colors.white,
    icon: Color(0xFF414C66),
    label: Color(0xFF5B667D),
    shadow: Color(0x40000000),
  );

  static const dark = PillNavStyle(
    bar: Color(0xFF1B2230),
    glow: Color(0xFF3388FD),
    accent: Color(0xFF5B9DFF),
    button: Color(0xFF3D8BFF),
    onButton: Colors.white,
    icon: Color(0xFFB4BDCF),
    label: Color(0xFF8E99AE),
    shadow: Color(0xB3000000),
  );
}

class _PillScope extends InheritedWidget {
  const _PillScope({required this.style, required super.child});

  final PillNavStyle style;

  static PillNavStyle of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PillScope>()?.style ??
      PillNavStyle.light;

  @override
  bool updateShouldNotify(_PillScope old) => old.style != style;
}

/// Full-width bottom bar with rounded corners, a round bump in the middle
/// holding a blue button, and four evenly spaced tabs.
///
/// Use in `Scaffold.bottomNavigationBar` together with `extendBody: true`
/// so the map shows behind the rounded corners and the bump.
///
/// [brightness] is optional: leave it null to follow the app theme (the app
/// has no dark theme yet, so that means light), or pass
/// `Brightness.dark` to preview the dark colors.
class PillNavBar extends StatelessWidget {
  const PillNavBar({
    super.key,
    required this.left,
    required this.right,
    required this.center,
    this.brightness,
  })  : assert(left.length == 2),
        assert(right.length == 2);

  final List<Widget> left;
  final List<Widget> right;

  /// Usually a [NavBarCenterButton].
  final Widget center;

  final Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    final mode = brightness ?? Theme.of(context).brightness;
    final style =
        mode == Brightness.dark ? PillNavStyle.dark : PillNavStyle.light;

    // The bar sits flush with the bottom of the screen; the system gesture
    // area is just extra background under the buttons.
    final inset = MediaQuery.paddingOf(context).bottom;

    return _PillScope(
      style: style,
      child: SizedBox(
        height: _kOverhang + _kBarHeight + inset,
        child: PhysicalShape(
          clipper: const _BarClipper(),
          color: style.bar,
          elevation: 6,
          shadowColor: style.shadow,
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _GlowPainter(style.glow)),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  top: _kOverhang,
                  height: _kBarHeight,
                  child: Row(
                    children: [
                      for (final item in left) Expanded(child: item),
                      const Expanded(child: SizedBox()), // middle slot
                      for (final item in right) Expanded(child: item),
                    ],
                  ),
                ),
                Positioned(
                  top: _kOverhang + _kHaloCenterY - _kButtonSize / 2,
                  left: 0,
                  right: 0,
                  child: Center(child: center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bar outline: rounded rectangle with a round bump in the top middle that
/// blends into the top edge with smooth curves.
class _BarClipper extends CustomClipper<Path> {
  const _BarClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    const r = _kCorner;
    const top = _kOverhang;
    const halo = _kHaloRadius;
    const f = _kFillet;
    const cy = _kHaloCenterY;

    final cx = w / 2;
    // Center of each smooth fillet curve (touches the top edge and the bump).
    final dx = math.sqrt((halo + f) * (halo + f) - (f + cy) * (f + cy));
    final haloCenter = Offset(cx, top + cy);
    final filletLeft = Offset(cx - dx, top - f);
    final filletRight = Offset(cx + dx, top - f);
    final a = math.atan2(cy + f, dx);

    return Path()
      ..moveTo(0, top + r)
      ..arcToPoint(const Offset(r, top), radius: const Radius.circular(r))
      ..lineTo(filletLeft.dx, top)
      ..arcTo(Rect.fromCircle(center: filletLeft, radius: f), math.pi / 2,
          -(math.pi / 2 - a), false)
      ..arcTo(Rect.fromCircle(center: haloCenter, radius: halo), -math.pi + a,
          math.pi - 2 * a, false)
      ..arcTo(Rect.fromCircle(center: filletRight, radius: f), math.pi - a,
          -(math.pi / 2 - a), false)
      ..lineTo(w - r, top)
      ..arcToPoint(Offset(w, top + r), radius: const Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
      ..close();
  }

  @override
  bool shouldReclip(_BarClipper old) => false;
}

/// Soft blue glow spreading from the middle button across the bar.
class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, _kOverhang + _kHaloCenterY);
    const radius = 78.0;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.color != color;
}

/// One icon + label tab for [PillNavBar].
class NavBarButton extends StatelessWidget {
  const NavBarButton({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.visible = true,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// When false the button is invisible and untappable but still takes up
  /// its slot, so the other buttons do not move. Changing it animates.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final style = _PillScope.of(context);

    return ExcludeSemantics(
      excluding: !visible,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: AnimatedScale(
            scale: visible ? 1 : 0.6,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            child: InkResponse(
              onTap: onTap,
              radius: 34,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? selectedIcon : icon,
                    color: selected ? style.accent : style.icon,
                    size: 26,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.1,
                      color: selected ? style.accent : style.label,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The round blue button in the middle of [PillNavBar].
class NavBarCenterButton extends StatelessWidget {
  const NavBarCenterButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final style = _PillScope.of(context);

    return Tooltip(
      message: tooltip ?? '',
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 5),
              color: style.glow.withValues(alpha: 0.38),
            ),
          ],
        ),
        child: Material(
          color: style.button,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: _kButtonSize,
              height: _kButtonSize,
              child: Icon(icon, color: style.onButton, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

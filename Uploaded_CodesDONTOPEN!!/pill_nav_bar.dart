import 'package:flutter/material.dart';

/// Floating, rounded bottom bar with a raised round button in the middle.
/// Looks right in light and dark mode: only colors change.
///
/// Put it in `Scaffold.bottomNavigationBar` with `extendBody: true` so the
/// page (the map) shows behind and around it.
class PillNavBar extends StatelessWidget {
  const PillNavBar({
    super.key,
    required this.left,
    required this.right,
    required this.center,
  })  : assert(left.length == 2),
        assert(right.length == 2);

  /// Exactly two buttons, left of the middle button.
  final List<Widget> left;

  /// Exactly two buttons, right of the middle button.
  final List<Widget> right;

  /// The raised middle button, usually a [NavBarCenterButton].
  final Widget center;

  static const double barHeight = 68;
  static const double _overhang = 14; // halo rises this far above the bar
  static const double _haloSize = 72;
  static const double _centerGap = 80; // room for the halo in the row

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final barColor = dark ? const Color(0xFF1B2130) : const Color(0xFFF5F8FE);
    final haloColor =
        Color.alphaBlend(primary.withValues(alpha: dark ? 0.22 : 0.14), barColor);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SizedBox(
          height: _overhang + barHeight,
          child: Stack(
            children: [
              // The bar itself.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: barHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                        color: Colors.black.withValues(alpha: dark ? 0.45 : 0.14),
                      ),
                    ],
                  ),
                  // Material so taps show an ink splash on top of the color.
                  child: Material(
                    color: barColor,
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        for (final item in left) Expanded(child: item),
                        const SizedBox(width: _centerGap),
                        for (final item in right) Expanded(child: item),
                      ],
                    ),
                  ),
                ),
              ),
              // Soft ring behind the middle button.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: _haloSize,
                    height: _haloSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: haloColor,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          color:
                              Colors.black.withValues(alpha: dark ? 0.25 : 0.06),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // The middle button, centered in the ring.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _haloSize,
                child: Center(child: center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One icon + label button for [PillNavBar].
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
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

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
                  Icon(selected ? selectedIcon : icon, color: color, size: 26),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 11,
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

/// The round accent button in the middle of [PillNavBar].
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
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip ?? '',
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              offset: const Offset(0, 4),
              color: scheme.primary.withValues(alpha: 0.38),
            ),
          ],
        ),
        child: Material(
          color: scheme.primary,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon, color: scheme.onPrimary, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

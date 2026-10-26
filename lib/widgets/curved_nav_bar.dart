import 'package:flutter/material.dart';

class CurvedNavBar extends StatelessWidget {
  const CurvedNavBar({super.key, required this.left, required this.right})
      : assert(left.length == 2),
        assert(right.length == 2);

  /// Exactly two widgets, laid out left of the center button.
  final List<Widget> left;

  /// Exactly two widgets, laid out right of the center button.
  /// A slot can hold a hidden [NavBarButton] to reserve its space.
  final List<Widget> right;

  /// Width reserved in the middle: button (56) + notch margins on both sides.
  static const double _centerGap = 76;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final item in left) Expanded(child: item),
          const SizedBox(width: _centerGap),
          for (final item in right) Expanded(child: item),
        ],
      ),
    );
  }
}

/// One icon + label button for [CurvedNavBar].
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
    final color =
        selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

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
              radius: 32,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selected ? selectedIcon : icon, color: color),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : null,
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

/// The raised round button that sits in the curve of [CurvedNavBar].
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
    return FloatingActionButton(
      heroTag: null,
      tooltip: tooltip,
      onPressed: onPressed,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 3,
      shape: const CircleBorder(),
      child: Icon(icon),
    );
  }
}

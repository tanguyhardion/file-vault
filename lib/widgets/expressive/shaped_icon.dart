import 'package:material_ui/material_ui.dart';

/// An icon set inside one of the M3 Expressive [MaterialShapes], used as the
/// hero graphic on sign-in and empty states.
class ShapedIcon extends StatelessWidget {
  const ShapedIcon(
    this.icon, {
    super.key,
    this.size = 96,
    this.shape,
    this.backgroundColor,
    this.foregroundColor,
  });

  final IconData icon;
  final double size;

  /// Defaults to [MaterialShapes.cookie9Sided].
  final RoundedPolygon? shape;

  /// Defaults to [ColorScheme.primaryContainer].
  final Color? backgroundColor;

  /// Defaults to [ColorScheme.onPrimaryContainer].
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: MaterialShapeBorder(
            shape: shape ?? MaterialShapes.cookie9Sided,
          ),
          color: backgroundColor ?? scheme.primaryContainer,
        ),
        child: Icon(
          icon,
          size: size * 0.45,
          color: foregroundColor ?? scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

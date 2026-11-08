import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The M3 Expressive loading indicator: a shape that spins while morphing
/// through a sequence of [MaterialShapes].
///
/// Use it for indeterminate waits of a screen or a section. For progress
/// inside a button or a row, a small [CircularProgressIndicator] still fits
/// better.
class LoadingIndicator extends StatefulWidget {
  const LoadingIndicator({
    super.key,
    this.size = 48,
    this.contained = false,
    this.color,
    this.semanticsLabel = 'Loading',
  });

  /// The size of the indicator's (square) container.
  final double size;

  /// Draws the shape on a circular [ColorScheme.primaryContainer] background.
  final bool contained;

  /// The color of the shape. Defaults to [ColorScheme.primary], or
  /// [ColorScheme.onPrimaryContainer] when [contained].
  final Color? color;

  final String semanticsLabel;

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with SingleTickerProviderStateMixin {
  static final List<RoundedPolygon> _shapes = [
    MaterialShapes.softBurst,
    MaterialShapes.cookie9Sided,
    MaterialShapes.pentagon,
    MaterialShapes.pill,
    MaterialShapes.sunny,
    MaterialShapes.cookie4Sided,
    MaterialShapes.oval,
  ];
  static const Duration _morphDuration = Duration(milliseconds: 650);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _morphDuration * _shapes.length,
  )..repeat();

  late final List<MaterialShapeBorder> _borders = [
    for (final shape in _shapes) MaterialShapeBorder(shape: shape),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color =
        widget.color ??
        (widget.contained ? scheme.onPrimaryContainer : scheme.primary);
    // Per spec the active shape fills 38 of a 48dp container.
    final inset = widget.size * (widget.contained ? 0.2 : 0.1);

    Widget indicator = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final n = _shapes.length;
        final position = _controller.value * n;
        final index = position.floor() % n;
        final t = Easing.emphasizedDecelerate.transform(position - position.floor());
        final shape = ShapeBorder.lerp(
          _borders[index],
          _borders[(index + 1) % n],
          t,
        )!;
        // Each morph also turns by 2/n of a revolution, so a full cycle of
        // shapes lands back on a whole number of turns and loops seamlessly.
        final angle = (index + t) * (4 * math.pi / n);
        return Transform.rotate(
          angle: angle,
          child: DecoratedBox(
            decoration: ShapeDecoration(shape: shape, color: color),
          ),
        );
      },
    );

    indicator = Padding(padding: EdgeInsets.all(inset), child: indicator);
    if (widget.contained) {
      indicator = DecoratedBox(
        decoration: ShapeDecoration(
          shape: const CircleBorder(),
          color: scheme.primaryContainer,
        ),
        child: indicator,
      );
    }

    return Semantics(
      label: widget.semanticsLabel,
      child: SizedBox.square(dimension: widget.size, child: indicator),
    );
  }
}

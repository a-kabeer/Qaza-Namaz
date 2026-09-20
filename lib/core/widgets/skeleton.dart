import 'package:flutter/material.dart';

/// Lightweight, dependency-free shimmer primitives for content loading.
///
/// The animation is intentionally subtle and respects the user's reduced-motion
/// preference. Colors are derived from the active Material 3 ColorScheme.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({
    super.key,
    required this.child,
    this.borderRadius,
  });

  final Widget child;
  final BorderRadiusGeometry? borderRadius;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Alignment> _begin;
  late final Animation<Alignment> _end;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _begin = AlignmentTween(
      begin: const Alignment(-2.2, 0),
      end: const Alignment(1.0, 0),
    ).animate(curve);
    _end = AlignmentTween(
      begin: const Alignment(-1.0, 0),
      end: const Alignment(2.2, 0),
    ).animate(curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled == _animationsDisabled) return;
    _animationsDisabled = disabled;
    if (disabled) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disableAnimations = _animationsDisabled;

    final base = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: .06),
      scheme.surfaceContainerLow,
    );
    final highlight = Color.alphaBlend(
      scheme.primary.withValues(alpha: .10),
      scheme.surfaceContainerHigh,
    );

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: base,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
      ),
      child: widget.child,
    );

    if (disableAnimations) {
      return ExcludeSemantics(child: content);
    }

    return AnimatedBuilder(
      animation: _controller,
      child: content,
      builder: (context, child) {
        final gradient = LinearGradient(
          begin: _begin.value,
          end: _end.value,
          colors: [base, highlight, base],
          stops: const [0.25, 0.5, 0.75],
        );
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: gradient.createShader,
          child: child,
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: SkeletonShimmer(
        borderRadius: borderRadius,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({
    super.key,
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: SkeletonShimmer(
        borderRadius: BorderRadius.circular(size),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class SkeletonText extends StatelessWidget {
  const SkeletonText({
    super.key,
    required this.width,
    this.height = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
  });

  final double width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}

class SkeletonSpacer extends StatelessWidget {
  const SkeletonSpacer(this.height, {super.key});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

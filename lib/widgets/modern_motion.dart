import 'package:flutter/material.dart';

/// Modern motion helpers used across the app.
///
/// - [StaggeredEntrance]: fade + slide-up entrance, staggered by [order].
/// - [PressableScale]: subtle press-down scale feedback for tappable cards.

class ModernMotion {
  ModernMotion._();

  static const Duration entrance = Duration(milliseconds: 420);
  static const Duration stagger = Duration(milliseconds: 60);
  static const Curve curve = Curves.easeOutCubic;
  static const double pressScale = 0.975;
}

/// Fades and slides its child up (+8% of its height) when first built.
/// [order] delays the effect so lists cascade in, one item after another.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.order,
    required this.child,
    this.enabled = true,
  });

  final int order;
  final Widget child;
  final bool enabled;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final int order = widget.enabled ? widget.order.clamp(0, 10) : 0;
    final double start = widget.enabled ? (order * 0.07).clamp(0.0, 0.6) : 0.0;

    _controller = AnimationController(
      vsync: this,
      duration: ModernMotion.entrance,
    );
    final CurvedAnimation curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1.0, curve: ModernMotion.curve),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.09),
      end: Offset.zero,
    ).animate(curved);

    if (start > 0) {
      Future<void>.delayed(ModernMotion.stagger * order, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Scales the child down slightly while the pointer/finger is pressed down,
/// giving every tappable card a soft, modern press feel.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.onTap == null) return widget.child;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? ModernMotion.pressScale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A premium page transition: the incoming screen fades in while sliding
/// up gently (replaces the default platform slide).
class FadeSlideRoute<T> extends PageRouteBuilder<T> {
  FadeSlideRoute({required WidgetBuilder builder})
    : super(
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => builder(context),
        transitionsBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
              Widget child,
            ) {
              final CurvedAnimation curved = CurvedAnimation(
                parent: animation,
                curve: ModernMotion.curve,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
      );
}

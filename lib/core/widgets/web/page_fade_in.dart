import 'package:flutter/material.dart';

/// Wrapper that fades in its child on first build.
/// Gives a smooth entrance when the page first loads.
class PageFadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double beginOffset;

  const PageFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
    this.beginOffset = 0.02,
  });

  @override
  State<PageFadeIn> createState() => _PageFadeInState();
}

class _PageFadeInState extends State<PageFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: Offset(0, widget.beginOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: jump to the settled frame — the page renders fully
    // visible instead of fading in. (The scheduled [Future.delayed] forward
    // is a no-op once the controller is already at 1.)
    if (_resolved) return;
    _resolved = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Opacity(
        opacity: _fadeAnim.value,
        child: Transform.translate(
          offset: _slideAnim.value,
          child: widget.child,
        ),
      ),
    );
  }
}

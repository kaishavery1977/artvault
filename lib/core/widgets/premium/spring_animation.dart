import 'package:flutter/material.dart';

/// Spring-animated widget that bounces in with physics-based motion.
///
/// Usage:
///   SpringWidget(
///     child: MyWidget(),
///     delay: Duration(milliseconds: 200),
///     spring: SpringType.bouncy,
///   )
enum SpringType {
  gentle, // Slow, elegant settle
  bouncy, // Playful overshoot
  snappy, // Quick, responsive
  heavy, // Weighted, dramatic
}

/// Predefined spring configurations.
class SpringConfig {
  final Duration duration;
  final double damping;
  final double stiffness;

  const SpringConfig({
    required this.duration,
    required this.damping,
    required this.stiffness,
  });

  static const gentle = SpringConfig(
    duration: Duration(milliseconds: 800),
    damping: 12,
    stiffness: 120,
  );

  static const bouncy = SpringConfig(
    duration: Duration(milliseconds: 600),
    damping: 8,
    stiffness: 180,
  );

  static const snappy = SpringConfig(
    duration: Duration(milliseconds: 350),
    damping: 15,
    stiffness: 300,
  );

  static const heavy = SpringConfig(
    duration: Duration(milliseconds: 900),
    damping: 10,
    stiffness: 80,
  );

  static SpringConfig forType(SpringType type) => switch (type) {
    SpringType.gentle => gentle,
    SpringType.bouncy => bouncy,
    SpringType.snappy => snappy,
    SpringType.heavy => heavy,
  };
}

/// A widget that animates in with spring physics.
class SpringWidget extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final SpringType spring;
  final Offset beginOffset;
  final double beginScale;
  final bool autoPlay;

  const SpringWidget({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.spring = SpringType.bouncy,
    this.beginOffset = const Offset(0, 0.15),
    this.beginScale = 0.9,
    this.autoPlay = true,
  });

  @override
  State<SpringWidget> createState() => _SpringWidgetState();
}

class _SpringWidgetState extends State<SpringWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    final config = SpringConfig.forType(widget.spring);

    _controller = AnimationController(vsync: this, duration: config.duration);

    // Use Curves.elasticOut for spring-like overshoot
    final curve = Curves.elasticOut;

    _scaleAnim = Tween<double>(
      begin: widget.beginScale,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: curve));

    _slideAnim = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: curve));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    if (widget.autoPlay) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnim.value,
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: Opacity(opacity: _fadeAnim.value, child: widget.child),
          ),
        );
      },
    );
  }
}

/// Staggered spring animations for a list of children.
class StaggeredSpring extends StatelessWidget {
  final List<Widget> children;
  final Duration staggerDelay;
  final SpringType spring;

  const StaggeredSpring({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 80),
    this.spring = SpringType.bouncy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++)
          SpringWidget(
            delay: staggerDelay * i,
            spring: spring,
            child: children[i],
          ),
      ],
    );
  }
}

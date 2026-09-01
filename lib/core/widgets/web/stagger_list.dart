import 'package:flutter/material.dart';

/// Animates children in sequentially with a stagger delay.
/// Each child fades in + slides up from below.
class StaggerList extends StatefulWidget {
  final List<Widget> children;
  final Duration staggerDelay;
  final Duration animationDuration;
  final double slideOffset;

  const StaggerList({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 40),
    this.animationDuration = const Duration(milliseconds: 350),
    this.slideOffset = 0.03,
  });

  @override
  State<StaggerList> createState() => _StaggerListState();
}

class _StaggerListState extends State<StaggerList> {
  final List<bool> _visible = [];

  @override
  void initState() {
    super.initState();
    _visible.addAll(List.filled(widget.children.length, false));
    _revealAll();
  }

  @override
  void didUpdateWidget(covariant StaggerList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      _visible.clear();
      _visible.addAll(List.filled(widget.children.length, false));
      _revealAll();
    }
  }

  void _revealAll() {
    for (var i = 0; i < widget.children.length; i++) {
      Future.delayed(widget.staggerDelay * i, () {
        if (mounted && i < _visible.length) {
          setState(() => _visible[i] = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < widget.children.length; i++)
          AnimatedOpacity(
            opacity: _visible[i] ? 1.0 : 0.0,
            duration: widget.animationDuration,
            curve: Curves.easeOutCubic,
            child: AnimatedSlide(
              offset: _visible[i]
                  ? Offset.zero
                  : Offset(0, widget.slideOffset),
              duration: widget.animationDuration,
              curve: Curves.easeOutCubic,
              child: widget.children[i],
            ),
          ),
      ],
    );
  }
}

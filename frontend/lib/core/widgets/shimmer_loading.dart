import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppTheme.darkCardElevated.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: AppTheme.darkBorder.withValues(alpha: _animation.value * 0.5),
              width: 0.8,
            ),
          ),
        );
      },
    );
  }
}

class ExpenseListSkeleton extends StatelessWidget {
  const ExpenseListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              const ShimmerSkeleton(width: 44, height: 44, borderRadius: 12),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerSkeleton(width: 130, height: 15, borderRadius: 6),
                    SizedBox(height: 7),
                    ShimmerSkeleton(width: 85, height: 11, borderRadius: 4),
                  ],
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShimmerSkeleton(width: 48, height: 11, borderRadius: 4),
                  SizedBox(height: 7),
                  ShimmerSkeleton(width: 58, height: 15, borderRadius: 6),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

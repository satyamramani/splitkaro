import 'package:flutter/material.dart';

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
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(
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
            color: Colors.grey.shade300.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
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
              const ShimmerSkeleton(width: 46, height: 46, borderRadius: 12),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerSkeleton(width: 140, height: 16),
                    SizedBox(height: 6),
                    ShimmerSkeleton(width: 90, height: 12),
                  ],
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShimmerSkeleton(width: 50, height: 12),
                  SizedBox(height: 6),
                  ShimmerSkeleton(width: 60, height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Static placeholder rows shown while a list loads.
///
/// Intentionally NOT animated: a shimmer/pulse is a continuous per-frame
/// repaint (and, wrapped around a ListView, a full-list rebuild every frame)
/// that competes with the network fetch + image decode it's covering for. On a
/// 2GB/1-core box that is exactly the kind of continuous animation the perf
/// rules forbid. A static skeleton reads the same and costs nothing while shown.
class NeonSkeletonList extends StatelessWidget {
  const NeonSkeletonList({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _SkeletonRow(shortLine: index.isOdd),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.shortLine});

  final bool shortLine;

  @override
  Widget build(BuildContext context) {
    final baseColor = Color.lerp(
      AppColors.panelStrong,
      AppColors.keyFill,
      0.3,
    )!;
    return Container(
      height: 74,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.panelStrong.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.panelBorderSoft),
      ),
      child: Row(
        children: [
          _Block(width: 92, color: baseColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: shortLine ? 0.62 : 0.86,
                  child: _Block(height: 16, color: baseColor),
                ),
                const SizedBox(height: AppSpacing.sm),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: shortLine ? 0.44 : 0.58,
                  child: _Block(height: 12, color: baseColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({this.width, this.height, required this.color});

  final double? width;
  final double? height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The `VIETKTV` wordmark: green `VIET` followed by white `KTV`, italic.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.fontSize = 44});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      letterSpacing: -0.5,
      height: 1,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'VIET',
            style: base.copyWith(color: AppColors.green),
          ),
          TextSpan(
            text: 'KTV',
            style: base.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

class MolinaBrand extends StatelessWidget {
  const MolinaBrand({super.key, this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: large ? 56 : 36,
        height: large ? 56 : 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/brand/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.directions_car, color: AppColors.gold),
        ),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rent a Car Molina',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: large ? 29 : 23,
                fontWeight: FontWeight.w600,
                color: AppColors.goldLight,
              ),
            ),
            if (large)
              const Text(
                'AUTORENT · EL SALVADOR',
                style: TextStyle(fontSize: 10, letterSpacing: 1.4),
              ),
          ],
        ),
      ),
    ],
  );
}

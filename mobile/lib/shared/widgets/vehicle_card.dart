import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/api.dart';

class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    this.imageUrl,
    this.price,
    this.onTap,
  });
  final String title, subtitle, status;
  final String? imageUrl, price;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: imageUrl == null
                ? const ColoredBox(
                    color: AppColors.elevated,
                    child: Icon(Icons.directions_car_outlined, size: 48),
                  )
                : Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    semanticLabel: title,
                    errorBuilder: (_, _, _) =>
                        localVehicleAsset(imageUrl) != null
                        ? Image.asset(
                            localVehicleAsset(imageUrl)!,
                            fit: BoxFit.cover,
                          )
                        : const ColoredBox(
                            color: AppColors.elevated,
                            child: Center(child: Text('Foto no disponible')),
                          ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: Space.sm),
                Text(subtitle),
                const SizedBox(height: Space.md),
                Text(
                  price == null ? 'Tarifa por confirmar' : '\$$price / día',
                  style: AppTypography.price(context),
                ),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Icon(
                      price != null
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      size: 16,
                      color: price != null
                          ? AppColors.success
                          : AppColors.goldLight,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        status,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

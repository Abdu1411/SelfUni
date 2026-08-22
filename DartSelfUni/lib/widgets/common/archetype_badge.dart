import 'package:flutter/material.dart';
import '../../models/card_model.dart';

class ArchetypeBadge extends StatelessWidget {
  final CardType type;
  final bool showLabel;
  final double size;

  const ArchetypeBadge({
    super.key,
    required this.type,
    this.showLabel = true,
    this.size = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final config = ArchetypeConfig.configs[type] ?? ArchetypeConfig.configs[CardType.concept]!;

    return Tooltip(
      message: config.description,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? 10.0 : 6.0,
          vertical: 5.0,
        ),
        decoration: BoxDecoration(
          color: config.backgroundColor,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: config.borderColor, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(config.icon, size: size, color: config.color),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                config.label,
                style: TextStyle(
                  fontSize: size,
                  fontWeight: FontWeight.bold,
                  color: config.color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

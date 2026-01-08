import 'package:flutter/material.dart';
import 'package:food_order/models/food.dart';

class FoodRatingDisplay extends StatelessWidget {
  const FoodRatingDisplay({
    super.key,
    required this.food,
    this.iconSize = 18,
    this.dense = false,
    this.zeroLabel = 'No reviews yet',
  });

  final Food food;
  final double iconSize;
  final bool dense;
  final String zeroLabel;

  @override
  Widget build(BuildContext context) {
    final bool hasRatings = food.ratingCount > 0;
    final double average = food.rating;
    final TextStyle valueStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: dense ? 13 : 15,
      color: hasRatings ? Colors.black87 : Colors.grey[500],
    );
    final TextStyle detailStyle = TextStyle(
      color: Colors.grey[600],
      fontSize: dense ? 12 : 14,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          size: iconSize,
          color: hasRatings ? Colors.amber : Colors.grey[400],
        ),
        SizedBox(width: dense ? 4 : 6),
        Text(
          hasRatings ? _formatAverage(average) : '--',
          style: valueStyle,
        ),
        SizedBox(width: dense ? 3 : 6),
        Text(
          hasRatings ? '(${food.ratingCount})' : zeroLabel,
          style: detailStyle,
        ),
      ],
    );
  }

  String _formatAverage(double value) {
    if (value <= 0) return '0';
    final bool isWholeNumber = value == value.roundToDouble();
    return isWholeNumber ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }
}

import 'package:flutter/material.dart';

import 'package:food_order/components/food_rating_display.dart';
import 'package:food_order/components/smart_image.dart';
import 'package:food_order/helper/currency_helper.dart';
import 'package:food_order/models/food.dart';

class FoodTile extends StatelessWidget {
  final Food food;
  final void Function()? onTap;

  const FoodTile({super.key, required this.food, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SmartImage(
                  imageUrl: food.imagePath,
                  width: 80,
                  height: 80,
                  borderRadius: 10,
                ),
                const SizedBox(
                  width: 15,
                ),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      formatPrice(food.price),
                      style: TextStyle(
                          color: Colors.green.shade300,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                    Text(_shortenDescription(food.description)),
                    const SizedBox(height: 6),
                    FoodRatingDisplay(
                      food: food,
                      dense: true,
                      iconSize: 16,
                    ),
                  ],
                )),
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiary,
                      shape: BoxShape.circle),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                  ),
                )
              ],
            ),
          ),
        ),
        Divider(
          color: Colors.amber.shade300,
          indent: 25,
          endIndent: 25,
        )
      ],
    );
  }

  String _shortenDescription(String description, {int maxLength = 50}) {
    if (description.length <= maxLength) {
      return description;
    } else {
      return '${description.substring(0, maxLength)}...';
    }
  }
}

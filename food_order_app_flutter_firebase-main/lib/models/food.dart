import 'package:cloud_firestore/cloud_firestore.dart';

class Food {
  final String? id;
  final String name;
  final String description;
  final String imagePath;
  final double price;
  final String category;
  final String? restaurantId;
  final double rating;
  final int ratingCount;

  Food({
    this.id,
    required this.name,
    required this.description,
    required this.imagePath,
    required this.price,
    required this.category,
    this.restaurantId,
    this.rating = 0,
    this.ratingCount = 0,
  });

  factory Food.fromMap(Map<String, dynamic> data, {String? id}) {
    return Food(
      id: id,
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      imagePath: _resolveImagePath(data),
      price: _parsePrice(data['price']),
      category: (data['category'] ?? '').toString(),
      restaurantId: _resolveRestaurantId(data['restaurantId']),
      rating: _parseRating(data['rating']),
      ratingCount: _parseRatingCount(data['ratingCount']),
    );
  }

  factory Food.fromDoc(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    return Food.fromMap(data, id: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imagePath': imagePath,
      'price': price,
      'category': category,
      if (restaurantId != null) 'restaurantId': restaurantId,
      'rating': rating,
      'ratingCount': ratingCount,
    };
  }

  static String _resolveImagePath(Map<String, dynamic> data) {
    final fromImagePath = data['imagePath'];
    final fromImage = data['image'];
    if (fromImagePath is String && fromImagePath.isNotEmpty) {
      return fromImagePath;
    }
    if (fromImage is String && fromImage.isNotEmpty) {
      return fromImage;
    }
    return '';
  }

  static String? _resolveRestaurantId(dynamic value) {
    if (value == null) return null;
    final asString = value.toString();
    return asString.isEmpty ? null : asString;
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return 0.0;
      return double.tryParse(trimmed) ?? 0.0;
    }
    return 0.0;
  }

  static double _parseRating(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble().clamp(0, 5);
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed == null) return 0.0;
      return parsed.clamp(0, 5);
    }
    return 0.0;
  }

  static int _parseRatingCount(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt().clamp(0, 1 << 31);
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed == null) return 0;
      return parsed.clamp(0, 1 << 31);
    }
    return 0;
  }
}

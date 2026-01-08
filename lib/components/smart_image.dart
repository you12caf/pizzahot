import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart'; // من أجل kIsWeb
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:food_order/services/app_cache_manager.dart'; // 👈 استيراد الخزنة التي أنشأناها

class SmartImage extends StatelessWidget {
  const SmartImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = 0,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // تحسين الرام: نحمل الصورة بضعف حجم العرض فقط وليس الحجم الأصلي
    final int memWidth = (width * 2).round().clamp(0, 1000);

    // ويدجت التحميل (Shimmer)
    Widget shimmer() => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        );

    // ويدجت الخطأ
    Widget errorBox() => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.fastfood,
            color: Colors.grey[400],
            size: width * 0.4, // حجم الأيقونة متجاوب
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: kIsWeb
          ? Image.network(
              imageUrl,
              width: width,
              height: height,
              fit: fit,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return shimmer();
              },
              errorBuilder: (context, error, stackTrace) => errorBox(),
            )
          : CachedNetworkImage(
              // 👇 هنا السر: نستخدم الخزنة الخاصة بنا بدلاً من الافتراضية
              cacheManager: AppCacheManager.instance,
              
              imageUrl: imageUrl,
              width: width,
              height: height,
              fit: fit,
              
              // تحسين الأداء
              memCacheWidth: memWidth,
              
              placeholder: (context, url) => shimmer(),
              errorWidget: (context, url, error) => errorBox(),
              fadeInDuration: const Duration(milliseconds: 200), // ظهور ناعم
            ),
    );
  }
}
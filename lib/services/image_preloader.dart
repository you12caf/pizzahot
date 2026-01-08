import 'package:flutter/foundation.dart'; // من أجل kIsWeb
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:food_order/services/app_cache_manager.dart';

class ImagePreloader {
  static final ImagePreloader _instance = ImagePreloader._internal();
  factory ImagePreloader() => _instance;
  ImagePreloader._internal();

  Future<void> preloadImages(BuildContext context, List<String> urls) async {
    debugPrint("🚀 [Silent Loader] Processing ${urls.length} images...");
    
    for (String url in urls) {
      if (url.isEmpty) continue;
      
      try {
        if (kIsWeb) {
          // 🌐 WEB MODE (PWA):
          // نستخدم ذاكرة المتصفح. دالة precacheImage تجبر المتصفح على تحميل الصورة
          // وحفظها في الكاش الخاص بكروم/سفاري.
          await precacheImage(NetworkImage(url), context);
        } else {
          // 📱 MOBILE MODE (APK):
          // نستخدم الخزنة الخاصة بنا (لمدة سنة)
          await AppCacheManager.instance.downloadFile(url);
        }
      } catch (e) {
        // نتجاهل الأخطاء بصمت
      }

      // استراحة صغيرة
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    debugPrint("✅ [Silent Loader] Finished.");
  }
}
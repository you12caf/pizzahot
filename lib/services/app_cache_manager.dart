import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppCacheManager {
  // اسم مفتاح الخزنة (كي لا يختلط مع ملفات أخرى)
  static const key = 'resto_dz_permanent_cache';

  // الإعدادات الصارمة
  static CacheManager instance = CacheManager(
    Config(
      key,
      // ✅ احتفظ بالصورة لمدة 365 يوماً (سنة كاملة)
      stalePeriod: const Duration(days: 365),
      // ✅ خزن حتى 500 صورة (يكفي لمنيو كامل)
      maxNrOfCacheObjects: 500,
      // ✅ استخدام نظام الملفات القياسي
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
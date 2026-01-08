import 'package:flutter/material.dart';
import 'package:food_order/components/food_tile.dart';
import 'package:food_order/components/nav_bar_menu_button.dart';
import 'package:food_order/components/smart_image.dart';
import 'package:food_order/config/app_config.dart';
import 'package:food_order/helper/currency_helper.dart';
import 'package:food_order/models/food.dart';
import 'package:food_order/models/restaurant.dart';
import 'package:food_order/pages/cart_page.dart';
import 'package:food_order/pages/food_page.dart';
import 'package:food_order/pages/notification_center_page.dart';
import 'package:food_order/services/image_preloader.dart'; // 👈 1. استيراد المحمل الصامت
import 'package:food_order/services/shop_time_helper.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_order/themes/restaurant_theme_provider.dart';
import 'dart:async';
import '../components/app_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // We use direct filtering now
  List<Map<String, String>> _categories = [];
  String _selectedCategoryId = 'all';

  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late PageController _bannerController;
  Timer? _bannerTimer;
  int _currentBannerPage = 0;
  final String _defaultRestaurantId = AppConfig.targetRestaurantId;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    _searchController.addListener(_onSearchChanged);
    _initializeMenu();
    // Ensure restaurant branding (logo & banners) is always loaded
    // with a safe fallback to AppConfig.targetRestaurantId.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Reuse the same logic used for menu initialization to resolve
      // the active restaurant id, with a hard fallback to AppConfig.targetRestaurantId
      // so branding (logo & banners) always loads.
      String? activeRestaurantId;

      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          final data = doc.data();
          activeRestaurantId =
              data != null ? data['restaurantId'] as String? : null;
        }
      } catch (_) {}

      activeRestaurantId ??= _defaultRestaurantId;

      final themeProvider =
          Provider.of<RestaurantThemeProvider>(context, listen: false);
      themeProvider.startListening(activeRestaurantId, context);

      // Check store working hours and show dialog if closed
      await _checkStoreWorkingHours(activeRestaurantId);
    });
    _startBannerTimer();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  /// Checks if the store is open and shows a dialog if closed.
  /// Allows user to continue browsing in "View Only" mode.
  Future<void> _checkStoreWorkingHours(String restaurantId) async {
    if (!mounted) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .get();
      final data = doc.data();

      if (data == null || data['workingHours'] == null) {
        // No working hours set, assume always open
        return;
      }

      final workingHours = data['workingHours'] as Map<String, dynamic>;
      final openStr = workingHours['open'] as String?;
      final closeStr = workingHours['close'] as String?;

      final isOpen = ShopTimeHelper.isShopOpen(openStr, closeStr);

      if (!isOpen && mounted) {
        final displayOpen = _formatTimeForDisplay(openStr);
        final displayClose = _formatTimeForDisplay(closeStr);

        _showClosedDialog(displayOpen, displayClose);
      }
    } catch (e) {
      debugPrint('Error checking store working hours: $e');
    }
  }

  /// Formats time string for Arabic display (e.g., "09:00" -> "9:00 ص")
  String _formatTimeForDisplay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';

    try {
      final parts = timeStr.split(':');
      if (parts.length < 2) return timeStr;

      int hour = int.parse(parts[0]);
      final minute = parts[1].padLeft(2, '0');
      final period = hour >= 12 ? 'م' : 'ص';

      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;

      return '$hour:$minute $period';
    } catch (e) {
      return timeStr;
    }
  }

  /// Shows a professional Arabic "Store Closed" dialog
  void _showClosedDialog(String openTime, String closeTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_clock,
                  size: 44,
                  color: Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'عذراً، المطعم مغلق الآن 🌙',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Working hours info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'ساعات العمل الرسمية',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTimeChip(
                            openTime, Icons.wb_sunny_rounded, Colors.orange),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.arrow_forward,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                        ),
                        _buildTimeChip(closeTime, Icons.nights_stay_rounded,
                            Colors.indigo),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFC6011),
                    side:
                        const BorderSide(color: Color(0xFFFC6011), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'تصفح القائمة فقط',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a time chip widget for the closed dialog
  Widget _buildTimeChip(String time, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            time,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      final theme =
          Provider.of<RestaurantThemeProvider>(context, listen: false);
      if (theme.bannerImages.length <= 1) return;
      _currentBannerPage = (_currentBannerPage + 1) % theme.bannerImages.length;
      if (_bannerController.hasClients) {
        _bannerController.animateToPage(_currentBannerPage,
            duration: const Duration(milliseconds: 500), curve: Curves.easeIn);
      }
    });
  }

  Future<void> _initializeMenu() async {
    final restaurant = Provider.of<Restaurant>(context, listen: false);
    String? activeRestaurantId;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final data = doc.data();
        activeRestaurantId =
            data != null ? data['restaurantId'] as String? : null;
      }
    } catch (_) {}

    activeRestaurantId ??= _defaultRestaurantId;

    // 1. Fetch Menu
    await restaurant.initializeMenu(restaurantId: activeRestaurantId);

    // 👇👇 2. استدعاء المحمل الصامت (بالاسم الصحيح) 👇👇
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ✅ التصحيح هنا: استخدمنا imagePath بدلاً من image
        final List<String> foodImages =
            restaurant.menu.map((e) => e.imagePath).toList();

        // 2. جمع صور البانر
        final theme =
            Provider.of<RestaurantThemeProvider>(context, listen: false);
        final List<String> bannerImages = theme.bannerImages;

        // 3. دمج القائمتين
        final allImages = [...foodImages, ...bannerImages];

        // انطلق! 🚀
        ImagePreloader().preloadImages(context, allImages);
      });
    }

    // 3. Fetch Categories
    try {
      final coll = FirebaseFirestore.instance
          .collection('restaurants')
          .doc(activeRestaurantId)
          .collection('categories');
      final snap = await coll.get();

      final loadedCategories = snap.docs.map((d) {
        final m = d.data();
        // TRICK: Use document ID if field 'id' is missing
        final String realId = (m['id'] != null && m['id'].toString().isNotEmpty)
            ? m['id'].toString()
            : d.id;

        return {
          'docId': d.id,
          'id': realId,
          'name': m['name'] as String? ?? 'Unnamed',
          'createdAt': m['createdAt'], // may be null or a Timestamp
        };
      }).toList();

      // Sort client-side: oldest first. Keep legacy items (null createdAt) at top.
      loadedCategories.sort((a, b) {
        final t1 = a['createdAt'];
        final t2 = b['createdAt'];
        if (t1 == null && t2 == null) return 0;
        if (t1 == null) return -1; // legacy -> keep at top
        if (t2 == null) return 1;
        try {
          final dt1 = t1 is Timestamp
              ? t1.toDate()
              : (t1 is DateTime ? t1 : DateTime.parse(t1.toString()));
          final dt2 = t2 is Timestamp
              ? t2.toDate()
              : (t2 is DateTime ? t2 : DateTime.parse(t2.toString()));
          return dt1.compareTo(dt2);
        } catch (_) {
          return 0;
        }
      });

      // Map to the simple string map the UI expects (drop createdAt)
      final mapped = loadedCategories
          .map((c) => {
                'docId': c['docId'] as String,
                'id': c['id'] as String,
                'name': c['name'] as String,
              })
          .toList(growable: false);

      if (mounted) {
        setState(() {
          _categories = [
            {'id': 'all', 'name': 'All'},
            ...mapped,
          ];
          _selectedCategoryId = 'all';
        });
      }
    } catch (e) {
      print("Error loading categories: $e");
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: NavBarMenuButton(scaffoldKey: _scaffoldKey),
        centerTitle: true,
        title: Consumer<RestaurantThemeProvider>(
          builder: (context, theme, _) {
            final url = theme.logoUrl?.trim() ?? '';
            if (url.startsWith('http')) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: SmartImage(
                  imageUrl: url,
                  height: 45,
                  width: 120,
                  fit: BoxFit.contain,
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Image.asset(
                'images/logo.png',
                height: 45,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Text(
                  'Home',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationCenterPage(),
                ),
              );
            },
            icon: const Icon(Icons.notifications_none, size: 28),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search for yummy food...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Banners with AspectRatio 2.1 (Standard Billboard Wide Format)
          Consumer<RestaurantThemeProvider>(builder: (context, theme, child) {
            if (theme.bannerImages.isNotEmpty) {
              return Container(
                margin: const EdgeInsets.only(top: 16),
                child: AspectRatio(
                  aspectRatio: 2.1,
                  child: PageView.builder(
                    controller: _bannerController,
                    itemCount: theme.bannerImages.length,
                    itemBuilder: (context, index) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: SmartImage(
                              imageUrl: theme.bannerImages[index],
                              width: constraints.maxWidth - 32,
                              height: constraints.maxHeight,
                              fit: BoxFit.cover,
                              borderRadius: 16,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          // Category Selector
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategoryId == cat['id'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = cat['id']!;
                    });
                    // DEBUG PRINT: Tell us what is clicked
                    print(
                        "👉 CLICKED CATEGORY: '${cat['name']}' (ID: ${cat['id']})");
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        cat['name']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Food List (With Debugging)
          Expanded(child: Consumer<Restaurant>(
            builder: (context, restaurant, child) {
              return _buildFoodList(restaurant.menu);
            },
          )),
        ],
      ),

      // Floating Cart
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          Consumer<Restaurant>(builder: (context, restaurant, child) {
        if (restaurant.cart.isEmpty) return const SizedBox.shrink();
        final total = restaurant.getTotalPrice();
        final count =
            restaurant.cart.fold(0, (sum, item) => sum + item.quantity);

        return GestureDetector(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const CartPage())),
          child: Container(
            height: 60,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Row(
              children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: Colors.white24, shape: BoxShape.circle),
                    child: Text("$count",
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Total",
                        style: TextStyle(color: Colors.white70, fontSize: 10)),
                    Text(formatPrice(total),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
                const Spacer(),
                const Text("View Cart",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFoodList(List<Food> allFoods) {
    List<Food> foodsToShow = allFoods.where((food) {
      final query = _searchController.text.trim().toLowerCase();
      bool matchesSearch =
          query.isEmpty || food.name.toLowerCase().contains(query);

      bool matchesCategory = true;
      if (_selectedCategoryId != 'all') {
        // Compare string IDs
        // DEBUG: Uncomment the line below to see mismatches in Console
        // print("🍔 CHECKING FOOD: '${food.name}' | Food Cat: '${food.category}' vs Selected: '$_selectedCategoryId'");

        matchesCategory = (food.category.toString().trim() ==
            _selectedCategoryId.toString().trim());
      }

      return matchesSearch && matchesCategory;
    }).toList();

    if (foodsToShow.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text("No foods found in '$_selectedCategoryId'",
                style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 5),
            // Helper text for debugging
            Text("(Make sure food category matches ID above)",
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
      itemCount: foodsToShow.length,
      itemBuilder: (context, index) {
        final food = foodsToShow[index];
        return FoodTile(
          food: food,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => FoodPage(food: food))),
        );
      },
    );
  }
}

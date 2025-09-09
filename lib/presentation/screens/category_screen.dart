import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/presentation/screens/home_screen.dart';
import 'package:startup_20/providers/bottom_nav_provider.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late ScrollController _scrollController;

  final Map<String, List<Category>> categorySections = {
    "Popular Categories": [
      Category(label: "Fruits", icon: Icons.apple),
      Category(label: "Veggies", icon: Icons.eco),
      Category(label: "Dairy", icon: Icons.local_drink),
      Category(label: "Bakery", icon: Icons.cake),
    ],
    "Services": [
      Category(label: "Plumber", icon: Icons.plumbing),
      Category(label: "Electrician", icon: Icons.electrical_services),
      Category(label: "Carpenter", icon: Icons.handyman),
      Category(label: "Painter", icon: Icons.format_paint),
    ],
    "Food": [
      Category(label: "Pizza", icon: Icons.local_pizza),
      Category(label: "Burger", icon: Icons.fastfood),
      Category(label: "Coffee", icon: Icons.local_cafe),
      Category(label: "Sweets", icon: Icons.icecream),
    ],
  };

  @override
  void initState() {
    super.initState();
    _handleScroll();
  }

  void _handleScroll() {
    _scrollController = ScrollController();

    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        Provider.of<BottomNavProvider>(context, listen: false).hideNavBar();
      } else if (_scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
        Provider.of<BottomNavProvider>(context, listen: false).showNavBar();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // 🔹 Top Bar + Location Selector
            CommonWidgets.topSection(context),

            // 🔹 Pinned Search Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: SearchBarHeader(child: _searchBar()),
            ),

            // 🔹 Scrollable Content
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Loop through category sections dynamically
                  ...categorySections.entries.map((entry) {
                    return buildCategorySection(entry.key, entry.value);
                  }).toList(),
                ]),
              ),
            ),

            // 🔹 Footer tagline outside padding, full width
            SliverToBoxAdapter(child: CommonWidgets.footerTagline()),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: "What service do you need?",
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.tune, color: AppColors.white),
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget buildCategorySection(String title, List<Category> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 Section Heading
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),

        // 🔹 Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, // 4 items per row
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 60,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Icon(category.icon, color: Colors.black54, size: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  category.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class Category {
  final String label;
  final IconData icon;

  Category({required this.label, required this.icon});
}

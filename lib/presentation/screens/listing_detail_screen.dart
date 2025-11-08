import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/data/models/review_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/presentation/screens/conversation/chat_room_screen.dart';
import 'package:startup_20/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ListingDetailScreen extends StatefulWidget {
  final Listing listing;
  final List<Listing> similarListings;

  const ListingDetailScreen({
    super.key,
    required this.listing,
    required this.similarListings,
  });

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _selectedRating = 0;
  bool _isChatLoading = false;
  bool _isSendingRewiew = false;

  bool _isFavorite = false;
  final TextEditingController _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  // ---------- Helper Methods ----------
  String getRatingLabel(double rating) {
    if (rating <= 1) return "Poor";
    if (rating <= 2) return "Good";
    if (rating <= 3) return "Very Good";
    if (rating <= 4) return "Excellent";
    return "Outstanding";
  }

  Future<void> _checkIfFavorite() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('favorites')
            .doc(widget.listing.listingId)
            .get();

    if (mounted) {
      setState(() {
        _isFavorite = doc.exists;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (AppAuthProvider.isAnonymousUser()) {
      CommonMethods.navigateToSignInScreen(context);
      return;
    }

    final userId = FirebaseAuth.instance.currentUser!.uid;
    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(widget.listing.listingId);

    try {
      if (_isFavorite) {
        setState(() => _isFavorite = false);
        await favRef.delete();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Removed from favorites")));
      } else {
        setState(() => _isFavorite = true);
        await favRef.set({
          'listingId': widget.listing.listingId,
          'name': widget.listing.name,
          'image': widget.listing.images.first.fullUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Added to favorites"),
            backgroundColor: AppColors.GREEN,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error updating favorites: $e")));
    }
  }

  Future<List<Listing>> fetchListings() async {
    if (widget.similarListings.isNotEmpty) {
      return widget.similarListings
          .where((listing) => listing.listingId != widget.listing.listingId)
          .toList();
    }

    final snapshot =
        await FirebaseFirestore.instance
            .collection("listings")
            .where("category", isEqualTo: widget.listing.category)
            .orderBy("createdAt", descending: true)
            .get();

    return snapshot.docs
        .map((doc) => Listing.fromJson(doc.data()))
        .where((listing) => listing.listingId != widget.listing.listingId)
        .toList();
  }

  Future<void> _submitReview() async {
    if (_isSendingRewiew) return; // Prevent multiple taps

    if (_selectedRating == 0 || _reviewController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please give a rating and review")),
      );
      return;
    }

    setState(() => _isSendingRewiew = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final listingRef = firestore
          .collection("listings")
          .doc(widget.listing.listingId);
      final reviewQuery =
          await listingRef
              .collection("reviews")
              .where(
                "userId",
                isEqualTo: FirebaseAuth.instance.currentUser!.uid,
              )
              .get();

      if (reviewQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You have already submitted a review")),
        );
        setState(() => _isSendingRewiew = false);
        return;
      }

      final text = _reviewController.text.trim();
      _reviewController.clear();

      final reviewRef = listingRef.collection("reviews").doc();
      final review = Review(
        reviewId: reviewRef.id,
        userId: FirebaseAuth.instance.currentUser!.uid,
        userName: FirebaseAuth.instance.currentUser?.displayName ?? "Anonymous",
        rating: _selectedRating,
        comment: text,
        createdAt: DateTime.now(),
      );

      await firestore.runTransaction((transaction) async {
        final listingSnapshot = await transaction.get(listingRef);

        if (!listingSnapshot.exists) {
          throw Exception("Listing not found");
        }

        final currentData = listingSnapshot.data()!;
        final currentRating = (currentData['rating'] ?? 0).toDouble();
        final currentReviews = (currentData['reviews'] ?? 0) as int;

        final totalRating = (currentRating * currentReviews) + _selectedRating;
        final newReviewCount = currentReviews + 1;
        final newAverageRating = totalRating / newReviewCount;

        transaction.set(reviewRef, review.toJson());
        transaction.update(listingRef, {
          'rating': double.parse(newAverageRating.toStringAsFixed(1)),
          'reviews': newReviewCount,
          'updatedAt': DateTime.now(),
        });
      });

      setState(() {
        _selectedRating = 0;
        _isSendingRewiew = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Review submitted successfully"),
          backgroundColor: AppColors.GREEN,
        ),
      );
    } catch (e) {
      debugPrint("❌ Error submitting review: $e");
      setState(() => _isSendingRewiew = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error submitting review: $e")));
    }
  }

  void _launchCaller(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      bool launched = await launchUrl(
        launchUri,
        mode: LaunchMode.platformDefault,
      );
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch dialer")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error launching dialer: $e")));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  // ---------- Widgets ----------
  Widget _buildImageCarousel(Listing listing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      height: 220,
      width: double.infinity,
      color: AppColors.GREY_SHADE_300,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: listing.images.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final imageUrl = listing.images[index].fullUrl;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => _FullScreenImageView(
                            images:
                                listing.images.map((e) => e.fullUrl).toList(),
                            initialIndex: index,
                          ),
                    ),
                  );
                },
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder:
                      (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                  errorWidget:
                      (context, url, error) =>
                          const Icon(Icons.broken_image, color: Colors.grey),
                ),
              );
            },
          ),
          _buildDotsIndicator(listing),
          _buildImageCounter(listing),
        ],
      ),
    );
  }

  Widget _buildDotsIndicator(Listing listing) {
    return Positioned(
      bottom: 10,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          listing.images.length,
          (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _currentPage == index ? 10 : 6,
            height: _currentPage == index ? 10 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _currentPage == index
                      ? AppColors.WHITE
                      : AppColors.WHITE.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCounter(Listing listing) {
    return Positioned(
      bottom: 10,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.GREY,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          "${_currentPage + 1}/${listing.images.length}",
          style: const TextStyle(color: AppColors.WHITE, fontSize: 10),
        ),
      ),
    );
  }

  Widget _buildListingInfo(Listing listing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side (Name + Location)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listing.name.length > 25
                    ? '${listing.name.substring(0, 25)}...'
                    : listing.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.GREY,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    listing.address.length > 30
                        ? '${listing.address.substring(0, 30)}...'
                        : listing.address,
                    style: const TextStyle(color: AppColors.GREY),
                  ),
                ],
              ),
            ],
          ),
          // Right side (Rating)
          Row(
            children: [
              const Icon(Icons.star, color: AppColors.AMBER, size: 20),
              const SizedBox(width: 4),
              Text(
                listing.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSellerSection(Listing listing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.GREY,
            child: Icon(Icons.person, size: 28, color: AppColors.WHITE),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listing.ownerName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text("Contributor", style: TextStyle(color: AppColors.GREY)),
            ],
          ),
          const Spacer(),
          _isChatLoading
              ? CircularProgressIndicator(
                color: AppColors.THEME_COLOR,
                padding: EdgeInsets.only(right: 20),
              )
              : TextButton.icon(
                onPressed: () {
                  if (listing.isClaimed) {
                    _handleChat();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Sorry, the chat service is currently unavailable for this seller.",
                        ),
                      ),
                    );
                  }
                },
                icon: Icon(
                  Icons.chat_bubble,
                  color:
                      !listing.isClaimed
                          ? AppColors.GREY
                          : AppColors.THEME_COLOR,
                  size: 20,
                ),
                label: Text(
                  "Chat",
                  style: TextStyle(
                    color:
                        !listing.isClaimed
                            ? AppColors.GREY
                            : AppColors.THEME_COLOR,
                    fontSize: 17,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildDescription(Listing listing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Text(
        listing.description,
        style: const TextStyle(color: AppColors.GREY, height: 1.4),
      ),
    );
  }

  Widget _buildReviewInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (index) {
            return IconButton(
              onPressed: () => setState(() => _selectedRating = index + 1.0),
              icon: Icon(
                index < _selectedRating ? Icons.star : Icons.star_border,
                color: AppColors.AMBER,
              ),
            );
          }),
        ),
        TextField(
          controller: _reviewController,
          decoration: InputDecoration(
            hintText: "Write a review...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon:
                _isSendingRewiew
                    ? Transform.scale(
                      scale: 0.5, // 0.5 = 50% of original size
                      child: const CircularProgressIndicator(
                        color: AppColors.THEME_COLOR,
                      ),
                    )
                    : IconButton(
                      icon: const Icon(Icons.send),
                      color: AppColors.THEME_COLOR,
                      onPressed: () {
                        AppAuthProvider.isAnonymousUser()
                            ? CommonMethods.navigateToSignInScreen(context)
                            : _submitReview();
                      },
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviews(Listing listing) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection("listings")
              .doc(listing.listingId)
              .collection("reviews")
              .orderBy("createdAt", descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews =
            snapshot.data!.docs
                .map(
                  (doc) => Review.fromJson(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ),
                )
                .toList();

        if (reviews.isEmpty) {
          return const Text("No reviews yet.");
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final r = reviews[index];
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.GREY_SHADE_300,
                child: Icon(Icons.person, color: AppColors.BLACK),
              ),
              title: Text(
                r.userName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis, // Truncate long names
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [const SizedBox(height: 4), Text(r.comment)],
              ),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ⭐ Rating stars above date
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      return Icon(
                        i < r.rating ? Icons.star : Icons.star_border,
                        size: 18,
                        color: AppColors.AMBER,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}",
                    style: const TextStyle(color: AppColors.GREY, fontSize: 12),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSimilarListings() {
    return FutureBuilder<List<Listing>>(
      future: fetchListings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return GridView.builder(
            padding: const EdgeInsets.all(15),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3 / 3.5,
            ),
            itemBuilder: (context, index) => CommonWidgets.shimmerlistingCard(),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final listings = snapshot.data ?? [];

        if (listings.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(15),
            child: const Text("No listings found"),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(15),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: listings.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 3 / 3.8,
          ),
          itemBuilder: (context, index) {
            final l = listings[index];
            return GestureDetector(
              onTap: () {
                CommonMethods.navigateToListingDetailScreen(
                  context,
                  l,
                  widget.similarListings,
                );
              },
              child: CommonWidgets.listingCard(l),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomButtons() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: AppColors.WHITE,
          boxShadow: [
            BoxShadow(
              color: AppColors.BLACK_12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.THEME_COLOR,
                  foregroundColor: AppColors.WHITE,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.directions),
                label: const Text("Direction"),
                onPressed: () async {
                  final lat = widget.listing.geo.lat;
                  final lng = widget.listing.geo.lng;

                  Uri url;

                  if (Platform.isIOS) {
                    // Apple Maps
                    url = Uri.parse("http://maps.apple.com/?daddr=$lat,$lng");
                  } else {
                    // Google Maps (Android or fallback)
                    url = Uri.parse(
                      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng",
                    );
                  }

                  if (!await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  )) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Could not open Maps")),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.THEME_COLOR,
                  foregroundColor: AppColors.WHITE,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.call),
                label: const Text("Call"),
                onPressed: () => _launchCaller(widget.listing.phone),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Main Build ----------
  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;

    return Scaffold(
      backgroundColor: AppColors.WHITE,
      appBar: AppBar(
        backgroundColor: AppColors.WHITE,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Details",
          style: TextStyle(color: AppColors.BLACK, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? AppColors.RED : AppColors.BLACK,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageCarousel(listing),
            const SizedBox(height: 15),
            _buildListingInfo(listing),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Divider(height: 30),
            ),
            _buildSellerSection(listing),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Divider(height: 30),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Description",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            _buildDescription(listing),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReviewInput(),
                  const Divider(height: 30),
                  Row(
                    children: [
                      const Text(
                        "Ratings & Reviews",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "(${listing.reviews})",
                        style: const TextStyle(color: AppColors.GREY),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildReviews(listing),
                  const Divider(height: 30),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Similar Listings",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            _buildSimilarListings(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  void _handleChat() async {
    if (AppAuthProvider.isAnonymousUser()) {
      CommonMethods.navigateToSignInScreen(context);
      return;
    }
    setState(() => _isChatLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser!;
    final ownerId = widget.listing.ownerId;

    if (currentUser.uid == ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot chat with yourself.")),
      );
      setState(() => _isChatLoading = false);

      return;
    }

    final conversationRef = FirebaseFirestore.instance.collection(
      "conversations",
    );

    // Check if conversation already exists between the two users
    final existingConversation =
        await conversationRef
            .where("type", isEqualTo: "direct")
            .where("participantIds", arrayContains: currentUser.uid)
            .get();

    String? existingId;
    for (var doc in existingConversation.docs) {
      final participants = List<String>.from(doc["participantIds"]);
      if (participants.contains(ownerId)) {
        existingId = doc.id;
        break;
      }
    }

    String conversationId;
    if (existingId != null) {
      conversationId = existingId;
    } else {
      // Create new conversation
      final newDoc = conversationRef.doc();
      conversationId = newDoc.id;
    }

    setState(() => _isChatLoading = false);

    // Navigate to Chat Room
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChatRoomScreen(
              conversationId: conversationId,
              otherUserId: widget.listing.ownerId,
              type: "direct",
              title: widget.listing.ownerName,
            ),
      ),
    );
  }
}

class _FullScreenImageView extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImageView({required this.images, this.initialIndex = 0});

  @override
  State<_FullScreenImageView> createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<_FullScreenImageView> {
  late PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          /// 🔹 Image PageView
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: widget.images[index],
                  fit: BoxFit.contain,
                  placeholder:
                      (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                  errorWidget:
                      (context, url, error) =>
                          const Icon(Icons.broken_image, color: Colors.white),
                ),
              );
            },
          ),

          /// 🔹 Close Button (top-right)
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          /// 🔹 Dots Indicator (bottom-center)
          Positioned(
            bottom: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.images.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 10 : 6,
                  height: _currentIndex == index ? 10 : 6,
                  decoration: BoxDecoration(
                    color:
                        _currentIndex == index
                            ? AppColors.THEME_COLOR
                            : Colors.white.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

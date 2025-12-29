import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/data/models/review_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/presentation/screens/add_listing_screen.dart';
import 'package:startup_20/presentation/screens/conversation/chat_room_screen.dart';
import 'package:startup_20/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

class ListingDetailScreen extends StatefulWidget {
  final Listing listing;
  final List<Listing> similarListings;
  final bool isPreview;
  final bool isEditing;

  const ListingDetailScreen({
    super.key,
    required this.listing,
    required this.similarListings,
    this.isPreview = false,
    this.isEditing = false,
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
  bool _isApproving = false;
  bool _isLoading = false;
  bool _isLiked = false;
  int _likes = 0;

  bool _isFavorite = false;
  final TextEditingController _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!widget.isPreview) {
      _checkIfFavorite();
      _checkIfLiked();
      _increaseViewCount();
    }
  }

  // ---------- Helper Methods ----------
  String getRatingLabel(double rating) {
    if (rating <= 1) return "Poor";
    if (rating <= 2) return "Good";
    if (rating <= 3) return "Very Good";
    if (rating <= 4) return "Excellent";
    return "Outstanding";
  }

  Future<void> _increaseViewCount() async {
    try {
      if (widget.isPreview) {
        return;
      }
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.listing.listingId)
          .update({'views': FieldValue.increment(1)});
    } catch (e) {
      debugPrint('❌ Failed to increase view count: $e');
    }
  }

  Future<void> _checkIfFavorite() async {
    if (AppAuthProvider.isAnonymousUser()) return;
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

  Future<void> _checkIfLiked() async {
    _likes = widget.listing.likes;
    if (AppAuthProvider.isAnonymousUser()) return;

    final userId = FirebaseAuth.instance.currentUser!.uid;

    final doc =
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(widget.listing.listingId)
            .collection('likedBy')
            .doc(userId)
            .get();

    if (mounted) {
      setState(() => _isLiked = doc.exists);
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
    if (widget.isPreview) return [];

    if (widget.similarListings.isNotEmpty) {
      return widget.similarListings
          .where((listing) => listing.listingId != widget.listing.listingId)
          .toList();
    }

    final snapshot =
        await FirebaseFirestore.instance
            .collection("listings")
            .where("category", isEqualTo: widget.listing.category)
            .where("verifiedBy", isNull: false)
            .orderBy("createdAt", descending: true)
            .get();

    return snapshot.docs
        .map((doc) => Listing.fromJson(doc.data()))
        .where((listing) => listing.listingId != widget.listing.listingId)
        .toList();
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

  Future<void> _handleListingApproval() async {
    try {
      if (widget.listing.addedBy == FirebaseAuth.instance.currentUser!.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You can't approve your own listing!")),
        );
        return;
      }
      setState(() => _isApproving = true);
      await FirebaseFirestore.instance
          .collection("listings")
          .doc(widget.listing.listingId)
          .update({
            "verifiedBy":
                FirebaseAuth.instance.currentUser?.displayName ?? "admin",
            "updatedAt": FieldValue.serverTimestamp(),
          });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Listing approved successfully!"),
          backgroundColor: AppColors.GREEN,
        ),
      );
      setState(() => _isApproving = false);
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.RED),
      );
      setState(() => _isApproving = false);
    }
  }

  Future<Uint8List?> _compressImage(
    File file, {
    required int minWidth,
    required int minHeight,
    required int quality,
  }) async {
    try {
      if (kIsWeb) {
        return await file.readAsBytes();
      }

      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
      );

      if (result == null) throw Exception("Image compression failed");
      return result;
    } catch (e) {
      debugPrint("Compression error: $e");
      try {
        return await file.readAsBytes();
      } catch (_) {
        return null;
      }
    }
  }

  Future<Map<String, dynamic>> _uploadImage(File file, String listingId) async {
    final storageRef = FirebaseStorage.instance.ref();
    final fileId = const Uuid().v4();

    // Full image compress
    final Uint8List? fullData = await _compressImage(
      file,
      minWidth: 1080,
      minHeight: 1080,
      quality: 75,
    );

    // Thumbnail compress
    final Uint8List? thumbData = await _compressImage(
      file,
      minWidth: 300,
      minHeight: 300,
      quality: 50,
    );

    // Upload full
    final fullRef = storageRef.child("listings/$listingId/full_$fileId.jpg");
    await fullRef.putData(
      fullData!,
      SettableMetadata(contentType: "image/jpeg"),
    );
    final fullUrl = await fullRef.getDownloadURL();

    // Upload thumbnail
    final thumbRef = storageRef.child("listings/$listingId/thumb_$fileId.jpg");
    await thumbRef.putData(
      thumbData!,
      SettableMetadata(contentType: "image/jpeg"),
    );
    final thumbUrl = await thumbRef.getDownloadURL();

    return {"fileId": fileId, "fullUrl": fullUrl, "thumbUrl": thumbUrl};
  }

  Future<List<Map<String, dynamic>>> _uploadImages(
    String listingId,
    List<File> files,
  ) async {
    List<Map<String, dynamic>> uploaded = [];

    for (var file in files) {
      final data = await _uploadImage(file, listingId);
      uploaded.add(data);
    }
    return uploaded;
  }

  /// Submit contribution
  Future<void> _submitContribution() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // validation unchanged...

      final firestore = FirebaseFirestore.instance;

      String listingId;
      String contributionId;

      if (widget.isEditing) {
        listingId = widget.listing.listingId;
        contributionId = widget.listing.contributionId;
      } else {
        listingId = firestore.collection("listings").doc().id;
        contributionId = firestore.collection("contributions").doc().id;
      }

      // ⭐ Upload only local images
      final uploadedNewImages = await _uploadImages(
        listingId,
        widget.listing.localImages ?? [],
      );

      //merge old + new images
      final finalImages = [
        ...widget.listing.images,
        ...uploadedNewImages.map(
          (img) => ImageFile(
            fileId: img["fileId"],
            fullUrl: img["fullUrl"],
            thumbUrl: img["thumbUrl"],
          ),
        ),
      ];

      debugPrint(widget.listing.openHours.toString());

      // ⭐ MODIFIED — create Listing model
      final listing = Listing(
        listingId: listingId,
        contributionId: contributionId,
        name: widget.listing.name,
        address: widget.listing.address,
        description: widget.listing.description,
        details: widget.listing.details,
        geo: widget.listing.geo,
        phone: widget.listing.phone,
        category: widget.listing.category,
        categoryId: widget.listing.categoryId,
        tags: widget.listing.tags,
        addedBy: widget.listing.addedBy,
        ownerId: widget.listing.ownerId,
        ownerName: widget.listing.ownerName,
        claimStatus: "pending",
        verifiedBy: null,
        createdAt: widget.listing.createdAt,
        updatedAt: DateTime.now(),
        images: finalImages,
        reviews: widget.listing.reviews,
        ratingCount: widget.listing.ratingCount,
        rating: widget.listing.rating,
        isClaimed: widget.listing.isClaimed,
        since: widget.listing.since,
        likes: widget.listing.likes,
        views: widget.listing.views,
        social: widget.listing.social,
        ratingStats: widget.listing.ratingStats,
        factorAvgRatings: widget.listing.factorAvgRatings,
        openHours: widget.listing.openHours,
      );

      //Update or Create
      if (widget.isEditing) {
        await firestore
            .collection("listings")
            .doc(listingId)
            .update(listing.toJson());
      } else {
        await firestore
            .collection("listings")
            .doc(listingId)
            .set(listing.toJson());
        await firestore.collection("contributions").doc(contributionId).set({
          "contributionId": contributionId,
          "userId": FirebaseAuth.instance.currentUser?.uid ?? "anonymous",
          "listingId": listingId,
          "type": "add",
          "status": "pending",
          "reviewedBy": null,
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing ? "Listing updated!" : "Contribution submitted!",
          ),
          backgroundColor: AppColors.GREEN,
        ),
      );

      Navigator.pop(context);
      Navigator.pop(context);
      if (widget.isEditing) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _shareListing() {
    final shareUrl =
        "https://needmet.in/listing/${widget.listing.listingId}";
    SharePlus.instance.share(
      ShareParams(text: 'Check out this listing on NeedMet:\n$shareUrl'),
    );
  }

  isURL(String text) {
    final urlPattern = RegExp(
      r'(https?:\/\/)?([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})(\/\S*)?',
    );
    return urlPattern.hasMatch(text);
  }

  Future<void> checkIfLiked(String listingId) async {
    if (AppAuthProvider.isAnonymousUser()) return;

    final userId = FirebaseAuth.instance.currentUser!.uid;

    final doc =
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(listingId)
            .collection('likedBy')
            .doc(userId)
            .get();

    if (mounted) {
      setState(() => _isLiked = doc.exists);
    }
  }

  Future<void> toggleLike(Listing listing) async {
    if (AppAuthProvider.isAnonymousUser()) {
      CommonMethods.navigateToSignInScreen(context);
      return;
    }

    if (widget.isPreview) return;

    // 🔹 Optimistic UI update
    final previousLiked = _isLiked;
    final previousLikes = _likes;

    _isLiked = !_isLiked;
    _likes += _isLiked ? 1 : -1;
    listing.likes = _likes;

    if (_likes < 0) _likes = 0;
    setState(() {});

    final userId = FirebaseAuth.instance.currentUser!.uid;
    final firestore = FirebaseFirestore.instance;

    final listingRef = firestore.collection('listings').doc(listing.listingId);
    final likeRef = listingRef.collection('likedBy').doc(userId);

    try {
      await firestore.runTransaction((transaction) async {
        final listingSnap = await transaction.get(listingRef);
        if (!listingSnap.exists) {
          throw Exception("Listing not found");
        }

        final data = listingSnap.data() as Map<String, dynamic>;
        final currentLikes = (data['likes'] as int?) ?? 0;

        final likeSnap = await transaction.get(likeRef);

        if (likeSnap.exists) {
          // 🔴 Unlike
          transaction.delete(likeRef);
          transaction.update(listingRef, {
            'likes': currentLikes > 0 ? currentLikes - 1 : 0,
          });
        } else {
          // 🟢 Like
          transaction.set(likeRef, {
            'userId': userId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(listingRef, {'likes': currentLikes + 1});
        }
      });
    } catch (e) {
      // 🔥 Rollback UI on failure
      _isLiked = previousLiked;
      _likes = previousLikes;
      setState(() {});

      debugPrint("❌ Like toggle failed: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to update like")));
    }
  }

  void showRateListingBottomSheet(BuildContext context, Listing listing) {
    if (widget.isPreview) {
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _MultiFactorRatingSheet(
            listing: listing,
            onSubmit: (factorRatings, comment) {
              _submitListingReview(
                listing: listing,
                factorRatings: factorRatings,
                comment: comment,
              );
            },
          ),
    );
  }

  Future<void> _submitListingReview({
    required Listing listing,
    required Map<String, double> factorRatings,
    required String comment,
  }) async {
    if (AppAuthProvider.isAnonymousUser()) {
      CommonMethods.navigateToSignInScreen(context);
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser!;
      final listingRef = firestore
          .collection('listings')
          .doc(listing.listingId);

      /// ✅ Remove unrated factors (0 values)
      final validValues = factorRatings.values.where((v) => v > 0).toList();

      if (validValues.isEmpty) {
        throw Exception("At least one rating is required");
      }

      /// ✅ Average rating (rounded to nearest whole number)
      final avgRating =
          (validValues.reduce((a, b) => a + b) / validValues.length)
              .roundToDouble();

      final isRatingOnly = comment.trim().isEmpty;

      await firestore.runTransaction((transaction) async {
        final listingSnap = await transaction.get(listingRef);
        if (!listingSnap.exists) {
          throw Exception("Listing not found");
        }

        final data = listingSnap.data() as Map<String, dynamic>;

        final currentRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
        final currentReviews = (data['reviews'] as int?) ?? 0;
        final currentRatingOnly = (data['ratingCount'] as int?) ?? 0;

        /// 🔹 Rating stats (5★, 4★, etc.)
        final Map<String, dynamic> ratingStats = Map<String, dynamic>.from(
          data['ratingStats'] ?? {},
        );

        final ratingKey = avgRating.toInt().toString();
        ratingStats[ratingKey] = (ratingStats[ratingKey] ?? 0) + 1;

        /// 🔹 Factor average rating
        final Map<String, dynamic> factorAvgRating = Map<String, dynamic>.from(
          data['factorAvgRatings'] ?? {},
        );

        factorRatings.forEach((key, value) {
          if (value <= 0) return;

          final oldAvg = (factorAvgRating[key] as num?)?.toDouble() ?? 0.0;

          final newAvg =
              ((oldAvg * currentReviews) + value) / (currentReviews + 1);

          factorAvgRating[key] = double.parse(newAvg.toStringAsFixed(1));
        });

        /// 🔹 Overall listing rating
        final newListingRating =
            ((currentRating * currentReviews) + avgRating) /
            (currentReviews + 1);

        /// 🔹 Create review
        final reviewRef = listingRef.collection('reviews').doc();
        final review = Review(
          reviewId: reviewRef.id,
          userId: user.uid,
          userName: user.displayName ?? "Anonymous",
          rating: avgRating,
          factorRatings: factorRatings,
          comment: comment,
          createdAt: DateTime.now(),
        );

        transaction.set(reviewRef, review.toJson());

        transaction.update(listingRef, {
          'rating': double.parse(newListingRating.toStringAsFixed(1)),
          'reviews': currentReviews + 1,
          'ratingCount':
              isRatingOnly ? currentRatingOnly + 1 : currentRatingOnly,
          'ratingStats': ratingStats,
          'factorAvgRatings': factorAvgRating,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Review submitted successfully"),
          backgroundColor: AppColors.GREEN,
        ),
      );
    } catch (e) {
      debugPrint("❌ Review submit failed: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to submit review")));
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
    final isPreview = widget.isPreview;

    // 🔥 Merge local + remote images
    final List<dynamic> combinedImages = [
      ...listing.images, // remote ImageFile models
      ...(isPreview ? (listing.localImages ?? []) : []), // local File objects
    ];

    final imageCount = combinedImages.length;

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
            itemCount: imageCount == 0 ? 1 : imageCount,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              if (imageCount == 0) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.grey, size: 50),
                      Text('No Image'),
                    ],
                  ),
                );
              }

              final img = combinedImages[index];

              // 🟦 Local file image
              if (img is File) {
                return Image.file(
                  img,
                  fit: BoxFit.cover,
                  width: double.infinity,
                );
              }

              // 🟩 Remote network image
              if (img is ImageFile) {
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
                    imageUrl: img.fullUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder:
                        (_, __) =>
                            const Center(child: CircularProgressIndicator()),
                    errorWidget:
                        (_, __, ___) =>
                            const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                );
              }

              return const SizedBox();
            },
          ),

          if (imageCount > 1) _buildDotsIndicator(listing, imageCount),
          if (imageCount > 1) _buildImageCounter(imageCount),
          _buildEstablishText(),
        ],
      ),
    );
  }

  Widget _buildDotsIndicator(Listing listing, int count) {
    return Positioned(
      bottom: 10,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
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

  Widget _buildImageCounter(int count) {
    return Positioned(
      bottom: 10,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.WHITE.withAlpha(50),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          "${_currentPage + 1}/$count",
          style: const TextStyle(color: AppColors.WHITE, fontSize: 10),
        ),
      ),
    );
  }

  Widget _buildEstablishText() {
    return Positioned(
      top: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.BLACK.withAlpha(60),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          "Since ${widget.listing.since}",
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

  Widget _buildEngagementSection(Listing listing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        decoration: BoxDecoration(color: AppColors.WHITE),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.GREY_SHADE_300),
                color: AppColors.WHITE,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 👍 Likes
                  _iconWithText(
                    icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    text: _likes.toString(),
                    isActive: _isLiked,
                    onTap: () => toggleLike(listing),
                  ),

                  Container(
                    margin: EdgeInsets.only(left: 10, right: 10),
                    height: 30,
                    width: 1,
                    color: Colors.grey.shade400,
                  ),

                  // 👁 Views
                  _iconWithText(
                    icon: Icons.remove_red_eye_outlined,
                    text: '${listing.views}',
                  ),
                ],
              ),
            ),

            const Spacer(),

            // 🌐 Website
            if (listing.social['Website'] != null)
              _socialIcon(
                imagePath: 'assets/images/website.svg',
                onTap: () => _openUrl(listing.social['Website']),
              ),

            // 💬 WhatsApp
            if (listing.social['WhatsApp'] != null)
              _socialIcon(
                imagePath: 'assets/images/whatsapp.svg',
                onTap: () => _openWhatsApp(listing.social['WhatsApp'] ?? ''),
              ),

            // 📘 Facebook
            if (listing.social['Facebook'] != null)
              _socialIcon(
                imagePath: 'assets/images/facebook.svg',
                onTap: () => _openUrl(listing.social['Facebook']),
              ),

            // 📸 Instagram
            if (listing.social['Instagram'] != null)
              _socialIcon(
                imagePath: 'assets/images/instagram.svg',
                onTap: () => _openUrl(listing.social['Instagram']),
              ),

            // LinkedIn
            if (listing.social['LinkedIn'] != null)
              _socialIcon(
                imagePath: 'assets/images/linkedin.svg',
                onTap: () => _openUrl(listing.social['LinkedIn']),
              ),
          ],
        ),
      ),
    );
  }

  Widget _iconWithText({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isActive ? AppColors.THEME_COLOR : AppColors.GREY,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.THEME_COLOR : AppColors.BLACK,
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialIcon({required String imagePath, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: GestureDetector(
        onTap: onTap,
        child: SvgPicture.asset(
          imagePath,
          width: 30,
          height: 30,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  void _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;

    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openWhatsApp(String phone) async {
    final url = Uri.parse("https://wa.me/$phone");
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Widget _buildSellerSection(Listing listing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.GREY,
            child: Text(
              CommonMethods.getInitials(listing.ownerName),
              style: TextStyle(color: AppColors.WHITE),
            ),
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
              Row(
                children: [
                  Text("Contributor", style: TextStyle(color: AppColors.GREY)),
                  SizedBox(width: 5),
                  SvgPicture.asset(
                    'assets/images/blueTick.svg',
                    width: 17,
                    height: 17,
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          _isChatLoading
              ? CircularProgressIndicator(
                color: AppColors.THEME_COLOR,
                padding: EdgeInsets.only(right: 20),
              )
              : listing.isClaimed
              ? TextButton.icon(
                onPressed: () {
                  if (widget.isPreview) {
                    return;
                  } else if (listing.isClaimed) {
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
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  Icons.chat_bubble,
                  color: AppColors.THEME_COLOR,
                  size: 20,
                ),
                label: Text(
                  "Chat",
                  style: TextStyle(color: AppColors.THEME_COLOR, fontSize: 17),
                ),
              )
              : TextButton.icon(
                onPressed: () {
                  if (widget.isPreview) {
                    return;
                  }
                  _openSupportChat();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.help, color: AppColors.THEME_COLOR, size: 20),
                label: Text(
                  "Need Help",
                  style: TextStyle(color: AppColors.THEME_COLOR, fontSize: 15),
                ),
              ),

          SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildDescription(Listing listing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Text(
        listing.description.isEmpty ? 'No description' : listing.description,
        style: const TextStyle(color: AppColors.GREY, height: 1.4),
      ),
    );
  }

  Widget buildRatingsOverview(Listing listing) {
    if (widget.isPreview) {
      /// 🟡 PREVIEW MODE — use local listing object
      return _buildRatingsContentPreview(
        rating: listing.rating,
        reviews: listing.reviews,
        ratingCount: listing.ratingCount,
        ratingStats: listing.ratingStats,
        factorAvgRatings: listing.factorAvgRatings,
        listing: listing,
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('listings')
              .doc(listing.listingId)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
        final reviews = (data['reviews'] as int?) ?? 0;
        final ratingCount = (data['ratingCount'] as int?) ?? 0;
        final ratingStats = data['ratingStats'] as Map<String, dynamic>? ?? {};
        final factorAvgRatings =
            data['factorAvgRatings'] as Map<String, dynamic>? ?? {};

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Ratings & Reviews",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      AppAuthProvider.isAnonymousUser()
                          ? CommonMethods.navigateToSignInScreen(context)
                          : showRateListingBottomSheet(context, listing);
                    },
                    child: const Text("Share Your Review"),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ratingSummary(rating, reviews, ratingCount),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 25),
                    height: 100,
                    width: 1,
                    color: Colors.grey.shade400,
                  ),
                  Expanded(child: _ratingDistribution(ratingStats)),
                ],
              ),
              SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _CategoryRating(
                    title: "Behaviour",
                    rating: factorAvgRatings['behaviour'] ?? 0.0,
                  ),
                  _CategoryRating(
                    title: "Quality",
                    rating: factorAvgRatings['quality'] ?? 0.0,
                  ),
                  _CategoryRating(
                    title: "Value",
                    rating: factorAvgRatings['value'] ?? 0.0,
                  ),
                  _CategoryRating(title: "Overall", rating: rating),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRatingsContentPreview({
    required double rating,
    required int reviews,
    required int ratingCount,
    required Map<String, dynamic> ratingStats,
    required Map<String, dynamic> factorAvgRatings,
    required Listing listing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Ratings & Reviews",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              OutlinedButton(
                onPressed: () {
                  AppAuthProvider.isAnonymousUser()
                      ? CommonMethods.navigateToSignInScreen(context)
                      : showRateListingBottomSheet(context, listing);
                },
                child: const Text("Share Your Review"),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ratingSummary(rating, reviews, ratingCount),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 25),
                height: 100,
                width: 1,
                color: Colors.grey.shade400,
              ),
              Expanded(child: _ratingDistribution(ratingStats)),
            ],
          ),

          const SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _CategoryRating(
                title: "Behaviour",
                rating:
                    (factorAvgRatings['behaviour'] as num?)?.toDouble() ?? 0.0,
              ),
              _CategoryRating(
                title: "Quality",
                rating:
                    (factorAvgRatings['quality'] as num?)?.toDouble() ?? 0.0,
              ),
              _CategoryRating(
                title: "Value",
                rating: (factorAvgRatings['value'] as num?)?.toDouble() ?? 0.0,
              ),
              _CategoryRating(title: "Overall", rating: rating),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ratingSummary(double rating, int reviews, int ratingOnlyCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          rating >= 4
              ? "Excellent"
              : rating >= 3
              ? "Good"
              : "Average",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),

        Row(
          children: List.generate(
            5,
            (index) => Icon(
              index < rating.round() ? Icons.star : Icons.star_border,
              color: AppColors.THEME_COLOR,
              size: 20,
            ),
          ),
        ),

        const SizedBox(height: 6),
        Text(
          "$ratingOnlyCount ratings and $reviews \nreviews",
          style: const TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _ratingDistribution(Map<String, dynamic>? ratingStats) {
    // Default rating buckets
    final Map<int, int> ratings = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

    // Merge Firestore data safely
    if (ratingStats != null) {
      for (final entry in ratingStats.entries) {
        final key = int.tryParse(entry.key);
        final value = entry.value;

        if (key != null && ratings.containsKey(key)) {
          ratings[key] = (value as num?)?.toInt() ?? 0;
        }
      }
    }

    // Find max value safely
    final int maxValue = ratings.values.reduce((a, b) => a > b ? a : b);

    return Column(
      children:
          ratings.entries.map((entry) {
            // 🔑 CRITICAL FIX: never allow NaN
            final double progress =
                maxValue == 0 ? 0.0 : entry.value / maxValue;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text("${entry.key}★"),
                  const SizedBox(width: 6),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progress, // always 0.0 → 1.0
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade300,
                      color: AppColors.THEME_COLOR,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(entry.value.toString()),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildOpenHoursTable(Listing listing) {
    if (listing.openHours.isEmpty) {
      return SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: const Text(
              "Open Hours",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.GREY_SHADE_300, width: 1),
            ),
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
              },
              children: [
                /// Header
                const TableRow(
                  decoration: BoxDecoration(color: Color(0xFFF5F5F5)),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(
                        child: Text(
                          "Day",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(
                        child: Text(
                          "Open",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(
                        child: Text(
                          "Close",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),

                /// Rows
                ...listing.openHours.entries.map((entry) {
                  final day = entry.key;
                  final hours = entry.value;

                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Center(child: Text(day)),
                      ),

                      /// Open Time
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Center(
                          child: Text(hours.closed ? 'Closed' : hours.close),
                        ),
                      ),

                      /// Close Time
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Center(
                          child: Text(hours.closed ? 'Closed' : hours.close),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviews(Listing listing) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection("listings")
              .doc(listing.listingId)
              .collection("reviews")
              .where("comment", isNotEqualTo: "")
              .orderBy("createdAt", descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
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

        // if (reviews.isEmpty) {
        //   return const Text("No reviews yet.");
        // }

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

  Widget _buildSubmitButton() {
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
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.THEME_COLOR,
            foregroundColor: AppColors.WHITE,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(widget.isEditing ? Icons.update : Icons.check),
          label: Text(widget.isEditing ? "Update " : "Submit"),
          onPressed: () {
            _submitContribution();
          },
        ),
      ),
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

  Widget _buildDetailsTable(Map<String, dynamic> details) {
    if (details.isEmpty) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Column(
        children: [
          const Center(
            child: Text(
              "Detailed Information",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.GREY_SHADE_300, width: 1),
            ),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(), 1: FlexColumnWidth()},
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: AppColors.GREY_SHADE_300,
                  width: 1,
                ),
                verticalInside: BorderSide(
                  color: AppColors.GREY_SHADE_300,
                  width: 1,
                ),
              ),
              children: [
                /// 🔹 Header Row
                TableRow(
                  decoration: BoxDecoration(
                    color: AppColors.GREY_SHADE_300.withOpacity(0.4),
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: Text(
                          "Details",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: Text(
                          "Info",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                /// 🔹 Data Rows
                ...details.entries.map((e) {
                  final key = e.key;
                  final value = e.value.toString();

                  return TableRow(
                    children: [
                      // Key column
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          key,
                          style: const TextStyle(
                            color: AppColors.BLACK,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      // Value column
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child:
                            isURL(value)
                                ? GestureDetector(
                                  onTap: () async {
                                    final uri = Uri.parse(
                                      value.startsWith("http")
                                          ? value
                                          : "https://$value",
                                    );
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                  child: Text(
                                    value,
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                )
                                : Text(
                                  key == 'Monthly Rent' ? '₹$value' : value,
                                  style: const TextStyle(
                                    color: AppColors.GREY,
                                    fontSize: 14,
                                  ),
                                ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReportPopup(String type, String targetId, String messageId) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController _controller = TextEditingController();

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Report',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: _controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "Write your reason...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = _controller.text.trim();

                final currentUser = FirebaseAuth.instance.currentUser!;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Report submitted successfully")),
                );

                Navigator.pop(context);

                await FirebaseFirestore.instance.collection("reports").add({
                  "type": type,
                  "reportedBy": currentUser.displayName,
                  "reportedByUid": currentUser.uid,
                  "reportedTo": widget.listing.ownerName,
                  "reportedToUid": widget.listing.ownerId,
                  "targetId": targetId,
                  "messageId": messageId,
                  "reason": text,
                  "status": "pending",
                  "createdAt": FieldValue.serverTimestamp(),
                });
              },
              child: const Text('Report'),
            ),
          ],
        );
      },
    );
  }

  // ---------- Main Build ----------
  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final appUser = context.watch<AppAuthProvider>().appUser;

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
          if (!widget.isPreview && widget.listing.verifiedBy != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? AppColors.RED : AppColors.BLACK,
              ),
              onPressed: () {
                _toggleFavorite();
              },
            ),
          if (!AppAuthProvider.isAnonymousUser() && !widget.isPreview)
            appUser?.role == 'admin'
                ? Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: AppColors.BLACK),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    AddListingScreen(existingListing: listing),
                          ),
                        );
                      },
                    ),
                    if (!widget.isPreview && widget.listing.verifiedBy == null)
                      _isApproving
                          ? SizedBox(
                            height: 35,
                            width: 35,
                            child: CircularProgressIndicator(
                              padding: EdgeInsets.all(8),
                              color: AppColors.THEME_COLOR,
                            ),
                          )
                          : IconButton(
                            icon: Icon(Icons.task_alt, color: AppColors.GREEN),
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              _handleListingApproval();
                            },
                          ),
                  ],
                )
                : SizedBox(),
          if (!widget.isPreview && widget.listing.verifiedBy != null)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Colors.black87),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: "share",
                      child: Row(
                        children: const [
                          Icon(Icons.share, color: Colors.blue, size: 20),
                          SizedBox(width: 10),
                          Text("Share"),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: "need help",
                      child: Row(
                        children: const [
                          Icon(
                            Icons.help_outline,
                            color: AppColors.THEME_COLOR,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text("Need Help"),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: "report",
                      child: Row(
                        children: const [
                          Icon(
                            Icons.flag_outlined,
                            color: AppColors.RED,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text("Report"),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
                if (value == "share") {
                  _shareListing();
                } else if (value == 'need help') {
                  _openSupportChat();
                } else if (value == "report") {
                  _showReportPopup('listing', widget.listing.listingId, '');
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
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
                _buildEngagementSection(listing),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Divider(height: 30),
                ),
                _buildSellerSection(listing),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Divider(height: 30),
                ),

                _buildOpenHoursTable(listing),

                _buildDetailsTable(listing.details),

                if (listing.details.isNotEmpty) const SizedBox(height: 10),
                if (listing.details.isNotEmpty)
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Divider(height: 30),
                ),

                buildRatingsOverview(widget.listing),

                if (widget.listing.reviews > 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Center(
                      child: Text(
                        "Reviews",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.BLACK_54,
                        ),
                      ),
                    ),
                  ),

                _buildReviews(widget.listing),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Divider(height: 30),
                ),

                if (!widget.isPreview)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "Similar Listings",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                if (!widget.isPreview) _buildSimilarListings(),
              ],
            ),
          ),
          // 🔹 Loading overlay
          if (_isLoading)
            Container(
              color: AppColors.BLACK_54,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.THEME_COLOR),
              ),
            ),
        ],
      ),
      bottomNavigationBar:
          widget.isPreview ? _buildSubmitButton() : _buildBottomButtons(),
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

  Future<void> _openSupportChat() async {
    setState(() => _isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      CommonMethods.navigateToSignInScreen(context);
      return;
    }

    final firestore = FirebaseFirestore.instance;

    // Step 1: Fetch all admins
    final adminSnap =
        await firestore
            .collection("users")
            .where("role", isEqualTo: "admin")
            .get();

    final adminIds = adminSnap.docs.map((e) => e.id).toList();

    // 2️⃣ Build participant map list
    List<Map<String, String>> participants = [];

    // Add current user
    participants.add({
      currentUser.uid: currentUser.displayName ?? "Unknown User",
    });

    // Add admins
    for (var doc in adminSnap.docs) {
      final adminId = doc.id;
      final adminName = doc['name'] ?? "Admin";
      participants.add({adminId: adminName});
    }
    // Participants
    final participantsIds = [currentUser.uid, ...adminIds];

    // Step 2: Generate deterministic conversationId (same support room reused)
    final conversationId = "support_${currentUser.uid}";

    final convRef = firestore.collection("conversations").doc(conversationId);
    final convSnap = await convRef.get();

    // Step 3: If chat does not exist → create it
    if (!convSnap.exists) {
      await convRef.set({
        "conversationId": conversationId,
        "type": "support",
        "initiatedBy": FirebaseAuth.instance.currentUser?.displayName ?? '',
        "participantIds": participantsIds,
        "participants": participants,
        "lastMessage": "Hi, I need assistance regarding this listing.",
        "lastMessageAt": FieldValue.serverTimestamp(),
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }

    // Auto-send first message
    final msgRef = convRef.collection("messages").doc();
    await msgRef.set({
      "messageId": msgRef.id,
      "senderId": currentUser.uid,
      "senderName": currentUser.displayName ?? "User",
      "text": "I need help with this listing",
      "attachments": {"type": "listing", "data": widget.listing.toJson()},
      "status": "sent",
      "createdAt": FieldValue.serverTimestamp(),
      "replyTo": null,
    });

    setState(() => _isLoading = false);

    // Step 4: Navigate to ChatRoomScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ChatRoomScreen(
              conversationId: conversationId,
              otherUserId: "support",
              type: "support",
              title: "Support 24/7",
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

class _CategoryRating extends StatelessWidget {
  final String title;
  final double rating;

  const _CategoryRating({required this.title, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 60,
              width: 60,
              child: CircularProgressIndicator(
                value: rating / 5,
                strokeWidth: 6,
                backgroundColor: AppColors.GREY_SHADE_300,
                color: AppColors.THEME_COLOR,
              ),
            ),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _MultiFactorRatingSheet extends StatefulWidget {
  final Listing listing;
  final Function(Map<String, double> ratings, String review) onSubmit;

  const _MultiFactorRatingSheet({
    required this.listing,
    required this.onSubmit,
  });

  @override
  State<_MultiFactorRatingSheet> createState() =>
      _MultiFactorRatingSheetState();
}

class _MultiFactorRatingSheetState extends State<_MultiFactorRatingSheet> {
  final Map<String, double> _ratings = {};
  final TextEditingController _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final factor in ratingFactors) {
      _ratings[factor.key] = 0;
    }
  }

  int get averageRating {
    final values = _ratings.values.where((v) => v > 0).toList();
    if (values.isEmpty) return 0;
    return (values.reduce((a, b) => a + b) / values.length).round();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.WHITE,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.GREY_SHADE_300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            Text(
              "Rate ${widget.listing.name}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            /// ⭐ Factor ratings
            ...ratingFactors.map((factor) {
              return _RatingRow(
                label: factor.label,
                rating: _ratings[factor.key]!,
                onChanged: (value) {
                  setState(() {
                    _ratings[factor.key] = value;
                  });
                },
              );
            }).toList(),

            const SizedBox(height: 12),

            /// ⭐ Average Rating Preview
            if (averageRating > 0)
              Row(
                children: [
                  const Text(
                    "Overall Rating:",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.THEME_COLOR,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            /// ✍️ Review text
            TextField(
              controller: _reviewController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Write your experience (optional)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.THEME_COLOR,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    averageRating == 0
                        ? null
                        : () {
                          widget.onSubmit(
                            _ratings,
                            _reviewController.text.trim(),
                          );
                          Navigator.pop(context);
                        },
                child: const Text(
                  "Submit Rating",
                  style: TextStyle(color: AppColors.WHITE),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final String label;
  final double rating;
  final ValueChanged<double> onChanged;

  const _RatingRow({
    required this.label,
    required this.rating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Row(
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () => onChanged(index + 1.0),
                icon: Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: AppColors.AMBER,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class RatingFactor {
  final String key;
  final String label;

  RatingFactor({required this.key, required this.label});
}

final List<RatingFactor> ratingFactors = [
  RatingFactor(key: 'behaviour', label: "Owner's Behaviour"),
  RatingFactor(key: 'quality', label: "Service / Product Quality"),
  RatingFactor(key: 'value', label: "Value for Money"),
];

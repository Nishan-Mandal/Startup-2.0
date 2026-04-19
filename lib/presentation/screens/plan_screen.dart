import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/core/services/razorpay_service.dart';
import 'package:startup_20/data/models/plan_model.dart';
import 'package:startup_20/data/models/user_model.dart';
import 'package:startup_20/main.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';

class PremiumPlanCard extends StatefulWidget {
  final AppUser? currentUser;

  const PremiumPlanCard({super.key, required this.currentUser});

  @override
  State<PremiumPlanCard> createState() => _PremiumPlanCardState();
}

class _PremiumPlanCardState extends State<PremiumPlanCard> {
  final razorpayService = RazorpayService();
  String _paymentType = "one_time";
  int selectedIndex = 1;
  String? appliedCoupon;
  String appliedCouponApplicableFor = "one_time";
  double discountAmount = 0.0;
  bool isApplying = false;
  bool _isPaymentSuccess = false;
  final TextEditingController couponController = TextEditingController();
  bool isCashSelected = false;
  final TextEditingController cashCodeController = TextEditingController();

  List<Plan> plans = [];
  bool isLoadingPlans = true;

  Future<void> _loadPlans() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('plans')
              .where('isActive', isEqualTo: true)
              .orderBy('createdAt')
              .get();

      final fetchedPlans =
          snapshot.docs.map((doc) => Plan.fromMap(doc.data(), doc.id)).toList();

      setState(() {
        plans = fetchedPlans;
        isLoadingPlans = false;
      });
    } catch (e) {
      debugPrint("Error loading plans: $e");

      setState(() {
        isLoadingPlans = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    razorpayService.init();

    _loadPlans();

    razorpayService.stream.listen((result) {
      switch (result.status) {
        case PaymentStatus.success:
          _handleSuccess(result);
          break;

        case PaymentStatus.failure:
          _handleFailure(result);
          break;

        case PaymentStatus.externalWallet:
          _handleWallet(result);
          break;
      }
    });
  }

  @override
  void dispose() {
    razorpayService.dispose();
    super.dispose();
  }

  void _handleSuccess(PaymentResult result) async {
    try {
      if (!mounted) return;

      //To avoid plan record creation on user documen
      if (_isPaymentSuccess) return;
      setState(() {
        _isPaymentSuccess = true;
      });

      CommonWidgets.showLoader(context);
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // ✅ ONLY VERIFY ONE-TIME
      if (_paymentType == "one_time") {
        double finalAmount = plans[selectedIndex].price - discountAmount;
        finalAmount = double.parse(finalAmount.toStringAsFixed(2));

        final callable = FirebaseFunctions.instance.httpsCallable(
          'verifyPayment',
        );

        await callable.call({
          "payment_id": result.paymentId,
          "order_id": result.orderId,
          "signature": result.signature,
          "userId": userId,
          "amount": finalAmount,
          "planName": plans[selectedIndex].planName,
          "duration": plans[selectedIndex].durationInDays,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Payment Successful ✅"),
          backgroundColor: AppColors.GREEN,
        ),
      );

      CommonWidgets.hideLoader();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
      );
    } catch (e) {
      debugPrint("Verification error: $e");
      CommonWidgets.hideLoader();
    }
  }

  void _handleFailure(PaymentResult result) {
    debugPrint("Payment Failed: ${result.message}");

    if (!mounted) return; // 🛑 CRITICAL FIX

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message ?? "Payment Failed")));
  }

  void _handleWallet(PaymentResult result) {
    debugPrint("Wallet Selected: ${result.message}");
  }

  void _buyPlan() async {
    try {
      CommonWidgets.showLoader(context);
      _paymentType = "one_time";
      final userId = FirebaseAuth.instance.currentUser!.uid;

      final selectedPlan =
          plans.isNotEmpty
              ? plans[selectedIndex.clamp(0, plans.length - 1)]
              : null;

      double finalAmount = selectedPlan!.price - discountAmount;
      finalAmount = double.parse(finalAmount.toStringAsFixed(2));

      final callable = FirebaseFunctions.instance.httpsCallable('createOrder');

      final response = await callable.call(<String, dynamic>{
        "amount": finalAmount * 100,
        "userId": userId,
        "type": "one_time",
        "planType": "pro",
      });

      final data = response.data;
      final orderId = data["id"];

      razorpayService.openOneTimePayment(
        key: plans[selectedIndex].apiKey,
        orderId: orderId,
        amount: data["amount"],
        name: "NeedMet",
        description: "Pro Plan",
        contact: widget.currentUser?.phone,
        email: null,
      );
      CommonWidgets.hideLoader();
    } catch (e) {
      CommonWidgets.hideLoader();
      debugPrint("Order error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to initiate payment")),
      );
    }
  }

  void _buyOnEmi() async {
    try {
      CommonWidgets.showLoader(context);
      _paymentType = "subscription";

      final selectedPlan =
          plans.isNotEmpty
              ? plans[selectedIndex.clamp(0, plans.length - 1)]
              : null;
      double finalAmount = selectedPlan!.price - discountAmount;
      finalAmount = double.parse(finalAmount.toStringAsFixed(2));

      final userId = FirebaseAuth.instance.currentUser!.uid;

      final callable = FirebaseFunctions.instance.httpsCallable(
        'createSubscription',
      );

      final response = await callable.call(<String, dynamic>{
        "userId": userId,
        "amount": finalAmount * 100,
        "duration": plans[selectedIndex].durationInDays,
        "planName": plans[selectedIndex].planName,
        "couponCode": appliedCoupon,
      });

      final data = response.data;
      final subscriptionId = data["id"];

      razorpayService.openSubscriptionPayment(
        key: plans[selectedIndex].apiKey,
        subscriptionId: subscriptionId,
        name: "NeedMet EMI",
        description: "Monthly Plan",
        contact: widget.currentUser?.phone,
        email: null,
      );
      CommonWidgets.hideLoader();
    } catch (e) {
      CommonWidgets.hideLoader();
      debugPrint("Subscription error: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to start EMI")));
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// ✅ ANIMATION (SIMPLE BUT COOL)
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 80,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                const Text(
                  "Payment Successful 🎉",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Your plan is now active",
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    navigatorKey.currentState?.pushNamedAndRemoveUntil(
                      '/home',
                      (route) => false,
                    );
                  },
                  child: const Text("Return Home"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlan =
        plans.isNotEmpty
            ? plans[selectedIndex.clamp(0, plans.length - 1)]
            : null;

    if (isLoadingPlans) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            "Manage Campaigns",
            style: TextStyle(color: AppColors.WHITE),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.WHITE),
          backgroundColor: AppColors.THEME_COLOR,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (plans.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            "Manage Campaigns",
            style: TextStyle(color: AppColors.WHITE),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.WHITE),
          backgroundColor: AppColors.THEME_COLOR,
        ),
        body: const Center(child: Text("No plans available")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Manage Campaigns",
          style: TextStyle(color: AppColors.WHITE),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.WHITE),
        backgroundColor: AppColors.THEME_COLOR,
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.WHITE,

            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.THEME_COLOR.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              /// 🔥 TITLE
              const Text(
                "NeedMet Plans",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(plans.length, (index) {
                    final plan = plans[index];
                    final isSelected = selectedIndex == index;

                    return GestureDetector(
                      onTap:
                          () => setState(() {
                            selectedIndex = index;
                            discountAmount = 0;
                            appliedCoupon = null;
                          }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.all(14),
                        width: 140, // 🔥 IMPORTANT (gives consistent card size)
                        decoration: BoxDecoration(
                          color:
                              isSelected ? AppColors.THEME_COLOR : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isSelected
                                    ? AppColors.THEME_COLOR
                                    : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (plan.isPopular)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "Most Popular",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            Text(
                              plan.durationInMonths,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              "₹${plan.price}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),

                            Text(
                              plan.planName,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isSelected ? Colors.white70 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        color: AppColors.THEME_COLOR,
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedPlan!.planName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Best for professionals",
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),

                  /// 💰 PRICE
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "₹${selectedPlan.price}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${(selectedPlan.durationInDays / 30).toInt()} months",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children:
                    selectedPlan.images.map((img) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: img,
                            width: 30,
                            height: 30,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    }).toList(),
              ),

              const SizedBox(height: 10),

              Column(
                children:
                    selectedPlan.featuresAvailable
                        .map((feature) => _Feature(text: feature))
                        .toList(),
              ),

              const SizedBox(height: 20),

              /// 🎟 COUPON SECTION
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Apply Coupon",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        /// INPUT
                        Expanded(
                          child: TextField(
                            controller: couponController,
                            decoration: InputDecoration(
                              hintText: "Enter coupon code",
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        /// APPLY BUTTON
                        ElevatedButton(
                          onPressed:
                              isApplying || appliedCoupon != null
                                  ? null
                                  : _applyCoupon,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                appliedCoupon == null
                                    ? AppColors.THEME_COLOR
                                    : AppColors.GREY,
                          ),
                          child:
                              isApplying
                                  ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    appliedCoupon == null ? "Apply" : "Applied",
                                    style: TextStyle(color: AppColors.WHITE),
                                  ),
                        ),
                      ],
                    ),

                    /// ✅ APPLIED STATE
                    if (appliedCoupon != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Coupon Applied: $appliedCoupon",
                            style: const TextStyle(color: Colors.green),
                          ),
                          GestureDetector(
                            onTap: _removeCoupon,
                            child: const Text(
                              "Remove",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    /// 💰 PRICE BREAKDOWN
                    if (appliedCoupon != null) ...[
                      Column(
                        children: [
                          _priceRow("Price", selectedPlan.price.toDouble()),

                          if (discountAmount > 0)
                            _priceRow(
                              "Discount",
                              discountAmount,
                              isDiscount: true,
                            ),

                          const Divider(),

                          _priceRow(
                            "Total",
                            double.parse(
                              (selectedPlan.price - discountAmount)
                                  .toStringAsFixed(2),
                            ),
                            isBold: true,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Checkbox(
                    value: isCashSelected,
                    onChanged: (value) {
                      setState(() {
                        isCashSelected = value ?? false;

                        if (!isCashSelected) {
                          cashCodeController.clear();
                        }
                      });
                    },
                  ),
                  const Text("Pay via Cash"),
                ],
              ),
              Column(
                children: [
                  /// 🔁 NORMAL PAYMENT (RAZORPAY)
                  if (!isCashSelected) ...[
                    Row(
                      children: [
                        Visibility(
                          visible:
                              (appliedCoupon == null ||
                                  (appliedCoupon != null &&
                                      appliedCouponApplicableFor ==
                                          "one_time")),
                          child: Expanded(
                            child: ElevatedButton(
                              onPressed: _buyPlan,
                              child: const Text("Buy Now"),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Visibility(
                          visible:
                              (appliedCoupon == null ||
                                  (appliedCoupon != null &&
                                      appliedCouponApplicableFor == "emi")),
                          child: Expanded(
                            child: OutlinedButton(
                              onPressed: _buyOnEmi,
                              child: const Text("Pay EMI"),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  /// 💵 CASH MODE
                  if (isCashSelected) ...[
                    /// 🔑 CODE INPUT
                    TextField(
                      controller: cashCodeController,
                      decoration: InputDecoration(
                        hintText: "Enter Cash Code",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.key),
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// 💰 CASH PAY BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.THEME_COLOR,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          _processCashPayment(cashCodeController.text.trim());
                        },
                        child: const Text(
                          "Confirm Cash Payment",
                          style: TextStyle(color: AppColors.WHITE),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processCashPayment(String code) async {
    if (code.isEmpty) {
      _showSnack("Please enter code");
      return;
    }

    // setState(() => isProcessingCash = true);
    CommonWidgets.showLoader(context);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final selectedPlan =
          plans.isNotEmpty
              ? plans[selectedIndex.clamp(0, plans.length - 1)]
              : null;

      double finalAmount = selectedPlan!.price - discountAmount;
      finalAmount = double.parse(finalAmount.toStringAsFixed(2));

      final callable = FirebaseFunctions.instance.httpsCallable(
        'verifyCashPayment',
      );

      await callable.call({
        "code": code,
        "userId": userId,
        "planName": selectedPlan.planName,
        "amount": finalAmount,
        "duration": selectedPlan.durationInDays,
      });

      CommonWidgets.hideLoader();

      _showSuccessDialog();
    } catch (e) {
      CommonWidgets.hideLoader();

      print("Cash payment error: $e");
      _showSnack("Invalid or expired code ❌");
    }
  }

  Future<void> _applyCoupon() async {
    final code = couponController.text.trim();
    FocusScope.of(context).unfocus();

    if (code.isEmpty) {
      _showSnack("Enter coupon code");
      return;
    }

    setState(() => isApplying = true);

    try {
      final selectedPlan =
          plans.isNotEmpty
              ? plans[selectedIndex.clamp(0, plans.length - 1)]
              : null;

      final callable = FirebaseFunctions.instance.httpsCallable('applyCoupon');

      final response = await callable.call({
        "code": code,
        "amount": selectedPlan?.price,
      });

      final data = response.data;

      // 🔥 SAFELY CONVERT TYPES
      final discountValue = (data["discountValue"] as num).toDouble();

      double calculatedDiscount = 0;

      if (data["discountType"] == "percentage") {
        calculatedDiscount = selectedPlan!.price * (discountValue / 100);
      } else {
        calculatedDiscount = discountValue;
      }

      setState(() {
        appliedCoupon = data["code"];
        appliedCouponApplicableFor = data["paymentType"];
        discountAmount = calculatedDiscount;
        discountAmount = double.parse(calculatedDiscount.toStringAsFixed(2));
      });

      _showSnack("Coupon applied successfully ✅");
    } catch (e) {
      print("Coupon error: $e");
      _showSnack("Invalid or expired coupon ❌");
    } finally {
      setState(() => isApplying = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      appliedCoupon = null;
      discountAmount = 0;
      couponController.clear();
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _priceRow(
    String title,
    double amount, {
    bool isBold = false,
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "${isDiscount ? '- ' : ''}₹${amount.toStringAsFixed(2)}",
            style: TextStyle(
              color: isDiscount ? Colors.green : Colors.black,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final String text;

  const _Feature({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // important
        children: [
          Icon(Icons.check_circle, size: 18, color: AppColors.THEME_COLOR),

          const SizedBox(width: 8),

          // ✅ This makes text wrap properly
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

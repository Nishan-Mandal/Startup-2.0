import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/user_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';

class AdminCodeScreen extends StatefulWidget {
  const AdminCodeScreen({super.key});

  @override
  State<AdminCodeScreen> createState() => _AdminCodeScreenState();
}

class _AdminCodeScreenState extends State<AdminCodeScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  late TabController _tabController;

  bool isLoading = false;

  final TextEditingController discountController = TextEditingController();
  final TextEditingController cashAmountController = TextEditingController();
  String selectedPaymentMode = "one_time";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    discountController.dispose();
    cashAmountController.dispose();
    super.dispose();
  }

  // ============================
  // 💰 GENERATE CASH CODE
  // ============================
  Future<void> generateCashCode() async {
    setState(() => isLoading = true);

    try {
      final amount = double.tryParse(cashAmountController.text.trim());

      if (amount == null || amount <= 0) {
        _showSnack("Enter valid amount");
        isLoading = false;
        return;
      }
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final userName = await CommonMethods.getUserData(userId, "name");


      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateCashCodes',
      );

      await callable.call({
        "count": 1,
        "amount": cashAmountController.text.trim(),
        "userId": FirebaseAuth.instance.currentUser!.uid,
        "ownerName": userName,
      });
      _showSnack("Cash code generated ✅");
    } catch (e) {
      _showSnack("Failed ❌");
    }

    setState(() {
      cashAmountController.clear();
      isLoading = false;
    });
  }

  // ============================
  // 🎟 GENERATE COUPON
  // ============================
  Future<void> generateCoupon() async {
    final discount = int.tryParse(discountController.text.trim());

    if (discount == null || discount <= 0) {
      _showSnack("Enter valid discount");
      return;
    }

    setState(() => isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final userName = await CommonMethods.getUserData(userId, "name");

      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateCoupon',
      );

      await callable.call({
        "discountType": "percentage",
        "discountValue": discount,
        "paymentType": selectedPaymentMode,
        "generatedBy": userId,
        "ownerName": userName,
      });

      discountController.clear();

      _showSnack("Coupon created ✅");
    } catch (e) {
      _showSnack("Error ❌");
    }

    setState(() => isLoading = false);
  }

  // ============================
  // 🚫 DEACTIVATE
  // ============================
  Future<void> deactivateCode(String collection, String docId) async {
    await db.collection(collection).doc(docId).update({
      "active": false,
      "expiresAt": FieldValue.serverTimestamp(),
    });

    _showSnack("Code deactivated");
  }

  // ============================
  // 🎯 UI
  // ============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Codes"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "Cash Codes"), Tab(text: "Coupons")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_cashSection(), _couponSection()],
      ),
    );
  }

  // ============================
  // 💰 CASH SECTION
  // ============================
  Widget _cashSection() {
    return Column(
      children: [
        _headerCard(
          title: "Generate Cash Code",
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: cashAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: "Cash Amount (₹)",
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: isLoading ? null : generateCashCode,
                icon: const Icon(Icons.add),
                label: const Text("Generate Code"),
              ),
            ],
          ),
        ),
        Expanded(child: _codeList("cash_codes")),
      ],
    );
  }

  // ============================
  // 🎟 COUPON SECTION
  // ============================
  Widget _couponSection() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔹 DISCOUNT INPUT
          TextField(
            controller: discountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: "Enter Discount %",
              labelText: "Discount",
              prefixIcon: const Icon(Icons.percent),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          /// 🔹 PAYMENT MODE + BUTTON
          Row(
            children: [
              /// DROPDOWN
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedPaymentMode,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: "one_time",
                          child: Text("One Time Payment"),
                        ),
                        DropdownMenuItem(
                          value: "emi",
                          child: Text("EMI (Subscription)"),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedPaymentMode = value!;
                        });
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              /// BUTTON
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : generateCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.THEME_COLOR,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      isLoading
                          ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text(
                            "Generate",
                            style: TextStyle(color: Colors.white),
                          ),
                ),
              ),
            ],
          ),
          Expanded(child: _codeList("coupons")),
        ],
      ),
    );
  }

  // ============================
  // 📦 HEADER CARD
  // ============================
  Widget _headerCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.WHITE,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.05)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // ============================
  // 📊 CODE LIST
  // ============================
  Widget _codeList(String collection) {
    return StreamBuilder(
      stream:
          db
              .collection(collection)
              .orderBy("createdAt", descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No codes"));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();

            return _codeCard(doc.id, data, collection);
          },
        );
      },
    );
  }

  Future<void> _confirmDeactivate(String collection, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Deactivate Code"),
          content: const Text("This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Deactivate"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await deactivateCode(collection, docId);
    }
  }

  // ============================
  // 💳 CODE CARD UI
  // ============================
  Widget _codeCard(String docId, Map<String, dynamic> data, String collection) {
    final isUsed = data["isUsed"] ?? false;
    final active = data["active"] ?? true;

    final createdAt = (data["createdAt"] as Timestamp?)?.toDate();
    final ownerName = data["ownerName"] ?? '';

    String status = "Deactivate Code";
    Color color = Colors.red;

    if (!active) {
      status = "Disabled";
      color = AppColors.GREY;
    } else if (isUsed) {
      status = "Used";
      color = AppColors.GREY;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔑 CODE + STATUS
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ LEFT SIDE (CODE + INFO)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // ✅ Code text
                        Expanded(
                          child: Text(
                            data["code"] ?? "N/A",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // ✅ Copy button
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: data["code"] ?? ""),
                            );
                            _showSnack("Copied!");
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // ✅ Coupon info
                    if (collection == "coupons")
                      Text(
                        data["discountType"] == "percentage"
                            ? "${data["discountValue"]}% OFF"
                            : "₹${data["discountValue"]} OFF",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ✅ RIGHT SIDE (STATUS BUTTON)
              GestureDetector(
                onTap: () {
                  if (active && !isUsed) {
                    _confirmDeactivate(collection, docId);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          if (ownerName != null)
            Text(
              "Generated By: $ownerName",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),


          /// 📅 DATE
          if (createdAt != null)
            Text(
              "Created: ${createdAt.toLocal()}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

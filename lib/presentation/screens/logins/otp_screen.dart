import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/core/services/notification_service.dart';
import 'package:startup_20/presentation/screens/bottom_nav_screen.dart';
import 'package:startup_20/providers/bottom_nav_provider.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String userName;
  final String phoneNumber;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.userName,
    required this.phoneNumber,
  });

  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _verifyOTP(String otp) async {
    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.isAnonymous) {
        // 🔗 Link phone credential to the existing anonymous user
        await user.linkWithCredential(credential);
        debugPrint("✅ Anonymous user successfully linked with phone number.");
      } else {
        // Normal sign-in flow (if not anonymous)
        await _auth.signInWithCredential(credential);
      }

      _saveUserData(widget.userName, widget.phoneNumber);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => ChangeNotifierProvider(
                create: (_) => BottomNavProvider(),
                child: const BottomNavScreen(),
              ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Invalid OTP: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveUserData(String name, String phone) async {
    // final _firebaseMessaging = FirebaseMessaging.instance;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snapshot = await doc.get();

      final token = await NotificationService.firebaseMessaging.getToken();

      // If user doesn't exist in Firestore → create new
      if (!snapshot.exists) {
        await doc.set({
          "userId": user.uid,
          "fcmToken": token,
          "name": name,
          "phone": phone,
          "role": "customer",
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });
        await user.updateDisplayName(name);
      } else {
        // 🔄 Existing user → just update updatedAt
        await doc.update({
          "updatedAt": FieldValue.serverTimestamp(),
          "fcmToken": token,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.WHITE,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 80),

              // Greeting
              Text(
                "Hi ${widget.userName}!",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Enter OTP sent to +91${widget.phoneNumber}",
                style: const TextStyle(fontSize: 16, color: AppColors.BLACK_54),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Pin Code Field
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: otpController,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                autoFocus: true,
                autoDismissKeyboard: true,
                enablePinAutofill: true,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 50,
                  fieldWidth: 50,
                  activeFillColor: AppColors.WHITE,
                  inactiveFillColor: AppColors.WHITE,
                  selectedFillColor: AppColors.WHITE,
                  activeColor: AppColors.RED,
                  selectedColor: AppColors.RED,
                  inactiveColor: AppColors.GREY_SHADE_300,
                ),
                animationDuration: const Duration(milliseconds: 300),
                enableActiveFill: true,
                onChanged: (value) {},
                onCompleted: (otp) => _verifyOTP(otp),
              ),

              const SizedBox(height: 30),

              // Verify Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () => _verifyOTP(otpController.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.RED,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: AppColors.WHITE,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            "Verify OTP",
                            style: TextStyle(fontSize: 18, color: AppColors.WHITE),
                          ),
                ),
              ),

              const SizedBox(height: 20),

              // Resend OTP
              TextButton(
                onPressed: () {
                  // TODO: Add resend OTP logic
                },
                child: const Text(
                  "Resend OTP",
                  style: TextStyle(color: AppColors.RED, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

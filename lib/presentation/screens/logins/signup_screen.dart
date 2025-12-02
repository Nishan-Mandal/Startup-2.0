import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/presentation/common_methods/cached_network_svg.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/presentation/screens/bottom_nav_screen.dart';
import 'package:startup_20/presentation/screens/legal_page_screen.dart';
import 'package:startup_20/providers/auth_provider.dart';
import 'package:startup_20/providers/bottom_nav_provider.dart';
import 'otp_screen.dart';

class SignUpScreen extends StatefulWidget {
  final String phoneNumber;
  final bool skip;
  const SignUpScreen({
    super.key,
    required this.phoneNumber,
    required this.skip,
  });

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = false;
  bool acceptedTerms = true;

  @override
  void initState() {
    super.initState();
    phoneController.text = widget.phoneNumber;
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter your name")));
      return;
    }

    if (phoneController.text.isEmpty || phoneController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid mobile number")),
      );
      return;
    }

    if (!acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please agree to Terms & Conditions")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: "+91${phoneController.text}", // India code
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message ?? "Error")));
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => OtpScreen(
                    verificationId: verificationId,
                    userName:
                        nameController.text
                            .trim(), // pass name to next screen if needed
                    phoneNumber: phoneController.text.trim(),
                  ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error sending OTP: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to send OTP. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.WHITE,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                widget.skip
                    ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () async {
                            CommonWidgets.showLoader(context);
                            await authProvider.signInAnonymously();
                            await FirebaseAuth.instance.currentUser
                                ?.updateDisplayName('Anonymous');
                            CommonWidgets.hideLoader();
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
                          },
                          child: Text("Skip"),
                        ),
                      ],
                    )
                    : SizedBox(),
                SizedBox(
                  height: 200,
                  width: 200,
                  child: Image.asset(
                    'assets/images/FindonLogo.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  "Sign Up!",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Sign up and help your neighbors today",
                  style: TextStyle(fontSize: 16, color: AppColors.BLACK_54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: nameController,
                  keyboardType: TextInputType.name,
                  decoration: const InputDecoration(
                    labelText: "Name",
                    border: OutlineInputBorder(),
                    hintText: "Enter your name",
                    hintStyle: TextStyle(color: AppColors.BLACK_54),
                  ),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Phone",
                    border: OutlineInputBorder(),
                    prefixText: "+91 ",
                    hintText: "Enter mobile number",
                    hintStyle: TextStyle(color: AppColors.BLACK_54),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: acceptedTerms,
                      activeColor: AppColors.THEME_COLOR,
                      onChanged: (value) {
                        setState(() => acceptedTerms = value ?? false);
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        // Go to Terms & Conditions page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => LegalPageScreen(
                                  pageId: "terms_of_service",
                                ),
                          ),
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          text: "I agree to the ",
                          style: const TextStyle(color: Colors.black87),
                          children: [
                            TextSpan(
                              text: "Terms & Conditions",
                              style: const TextStyle(
                                color: AppColors.THEME_COLOR,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Send OTP Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.THEME_COLOR,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child:
                        isLoading
                            ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.WHITE,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              "Submit",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.WHITE,
                              ),
                            ),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context); // go back to Sign In screen
                      },
                      child: const Text(
                        "Sign In",
                        style: TextStyle(
                          color: AppColors.THEME_COLOR,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

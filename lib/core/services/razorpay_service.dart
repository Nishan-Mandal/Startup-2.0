import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';

enum PaymentStatus { success, failure, externalWallet }

class PaymentResult {
  final PaymentStatus status;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? message;
  final int? errorCode;
  final dynamic errorData;

  PaymentResult({
    required this.status,
    this.paymentId,
    this.orderId,
    this.signature,
    this.message,
    this.errorCode,
    this.errorData,
  });
}

class RazorpayService {
  static final RazorpayService _instance = RazorpayService._internal();
  factory RazorpayService() => _instance;

  RazorpayService._internal();

  Razorpay? _razorpay;

  final StreamController<PaymentResult> _controller =
      StreamController.broadcast();

  Stream<PaymentResult> get stream => _controller.stream;

  // ============================
  // INIT
  // ============================
  void init() {
    _razorpay ??= Razorpay();

    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleWallet);
  }

  void dispose() {
    _razorpay?.clear();
  }

  // ============================
  // 💳 ONE-TIME PAYMENT
  // ============================
  void openOneTimePayment({
    required String key,
    required String orderId,
    required int amount,
    required String name,
    required String description,
    String? contact,
    String? email,
  }) {
    try {
      final options = {
        'key': key,
        'amount': amount,
        'order_id': orderId,
        'name': name,
        'description': description,

        'retry': {'enabled': true, 'max_count': 1},
        'send_sms_hash': true,

        'prefill': {'contact': contact ?? '', 'email': email ?? ''},

        'external': {
          'wallets': ['paytm'],
        },
      };

      _razorpay?.open(options);
    } catch (e) {
      _controller.add(
        PaymentResult(status: PaymentStatus.failure, message: e.toString()),
      );
    }
  }

  // ============================
  // 🔁 SUBSCRIPTION PAYMENT
  // ============================
  void openSubscriptionPayment({
    required String key,
    required String subscriptionId,
    required String name,
    required String description,
    String? contact,
    String? email,
  }) {
    try {
      final options = {
        'key': key,
        'subscription_id': subscriptionId,

        // 🔥 Same improvements here
        'retry': {'enabled': true, 'max_count': 1},
        'send_sms_hash': true,

        'name': name,
        'description': description,

        'prefill': {'contact': contact ?? '', 'email': email ?? ''},

        'external': {
          'wallets': ['paytm'],
        },
      };

      _razorpay?.open(options);
    } catch (e) {
      _controller.add(
        PaymentResult(status: PaymentStatus.failure, message: e.toString()),
      );
    }
  }

  // ============================
  // 🔔 HANDLERS
  // ============================

  void _handleSuccess(PaymentSuccessResponse response) {
    _controller.add(
      PaymentResult(
        status: PaymentStatus.success,
        paymentId: response.paymentId,
        orderId: response.orderId, // ✅ ADD
        signature: response.signature,
      ),
    );
  }

  void _handleError(PaymentFailureResponse response) {
    String errorMessage;

    // 🔥 Handle all cases safely
    if (response.message != null && response.message!.isNotEmpty) {
      errorMessage = response.message!;
    } else if (response.code == Razorpay.PAYMENT_CANCELLED) {
      errorMessage = "Payment cancelled by user";
    } else {
      errorMessage = "Something went wrong. Please try again.";
    }

    _controller.add(
      PaymentResult(
        status: PaymentStatus.failure,
        message: errorMessage,
        errorCode: response.code,
        errorData: response.error,
      ),
    );
  }

  void _handleWallet(ExternalWalletResponse response) {
    _controller.add(
      PaymentResult(
        status: PaymentStatus.externalWallet,
        message: response.walletName,
      ),
    );
  }
}

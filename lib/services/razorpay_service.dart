// lib/services/razorpay_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayService {
  late Razorpay _razorpay;
  
  // Callback functions to handle UI updates from the Service
  final Function(String paymentId) onSuccess;
  final Function(String errorMessage) onFailure;

  RazorpayService({required this.onSuccess, required this.onFailure}) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  /// Opens the Razorpay Checkout form.
  void openCheckout({
    required double amount,
    required String email,
    required String phone,
    String? description,
    String? orderId,
  }) {
    String? keyId;

    // 1. Safe Access to Environment Variables
    try {
      if (dotenv.isInitialized) {
        keyId = dotenv.env['RAZORPAY_KEY_ID'];
      } else {
        debugPrint("⚠️ Warning: DotEnv is not initialized. Cannot read RAZORPAY_KEY_ID.");
      }
    } catch (e) {
      debugPrint("❌ Error accessing .env variables: $e");
    }

    // 2. Auto-Fix Malformed Keys (Security & UX Fix)
    // If the user pasted "KeyID,KeySecret" (common mistake), we strip the secret part.
    if (keyId != null && keyId.contains(',')) {
      debugPrint("⚠️ Warning: Malformed RAZORPAY_KEY_ID detected (Comma found). Auto-fixing...");
      keyId = keyId.split(',')[0].trim();
    }

    // 3. Validation
    if (keyId == null || keyId.isEmpty) {
      debugPrint("❌ Critical Error: RAZORPAY_KEY_ID is missing or invalid.");
      onFailure("Configuration Error: Payment Gateway Key is missing. Check .env file.");
      return;
    }

    // 4. Prepare Payment Options
    var options = {
      'key': keyId,
      'amount': (amount * 100).toInt(), // Razorpay takes amount in paise
      'name': 'DocVartaa',
      'description': description ?? 'Wallet Recharge',
      'retry': {'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
      'prefill': {
        'contact': phone,
        'email': email
      },
      'theme': {
        'color': '#1E88E5' // DocVartaa Brand Color
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    if (orderId != null) {
      options['order_id'] = orderId;
    }

    // 5. Launch Razorpay
    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('❌ Razorpay Startup Error: $e');
      onFailure("Failed to initialize payment gateway: $e");
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint("✅ Payment Success: ${response.paymentId}");
    final paymentId = response.paymentId ?? 'Unknown_ID';
    onSuccess(paymentId);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("❌ Payment Error: Code ${response.code} - ${response.message}");
    
    String readableError = "Payment Failed";
    
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      readableError = "Payment Cancelled by User";
    } else if (response.code == Razorpay.NETWORK_ERROR) {
      readableError = "Network Error. Please check your connection.";
    } else {
      readableError = response.message ?? "An unknown error occurred during payment.";
    }
    
    onFailure(readableError);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("⚠️ External Wallet Selected: ${response.walletName}");
    onFailure("External Wallet '${response.walletName}' is not supported.");
  }

  void dispose() {
    _razorpay.clear();
  }
}
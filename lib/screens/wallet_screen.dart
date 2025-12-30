// lib/screens/wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/wallet_service.dart';
import '../services/razorpay_service.dart';

class WalletScreen extends StatefulWidget {
  final double? rechargeAmount; // Optional: Auto-trigger specific amount
  const WalletScreen({super.key, this.rechargeAmount});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  // Services
  final WalletService _walletService = WalletService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late RazorpayService _razorpayService;

  // Controllers
  final TextEditingController _amountController = TextEditingController();

  // State Variables
  double _balance = 0.0;
  bool _loading = true;
  double _selectedAmount = 0.0;
  String? _errorText;

  // Preset Recharge Packs
  final List<double> _rechargeOptions = [500, 1000, 2000, 5000];

  @override
  void initState() {
    super.initState();
    _loadBalance();

    // Initialize Razorpay
    _razorpayService = RazorpayService(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentFailure,
    );

    // Handle Auto-Trigger
    if (widget.rechargeAmount != null) {
      _selectAmount(widget.rechargeAmount!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initiatePayment();
      });
    }
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final bal = await _walletService.getBalance();
      if (mounted) {
        setState(() {
          _balance = bal;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint("Error loading balance: $e");
    }
  }

  void _selectAmount(double amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toInt().toString();
      _errorText = null;
    });
  }

  void _initiatePayment() {
    // 1. Get Amount
    double? amount = double.tryParse(_amountController.text);

    // 2. Validate Minimum Amount (₹500)
    if (amount == null || amount < 15) {
      setState(() => _errorText = "Minimum recharge amount is ₹500");
      return;
    }

    setState(() {
      _loading = true; // START SPINNER
      _selectedAmount = amount;
    });

    final user = _auth.currentUser;
    final email = user?.email ?? 'guest@docvartaa.com';
    final phone = user?.phoneNumber ?? '9876543210';

    // 3. Open Gateway with Safety Catch
    try {
      _razorpayService.openCheckout(
        amount: amount,
        email: email,
        phone: phone,
        description: "Wallet Recharge: ₹${amount.toInt()}",
      );
    } catch (e) {
      debugPrint("❌ Payment Launch Error: $e");
      // ✅ CRITICAL FIX: Ensure spinner stops if launch fails
      _handlePaymentFailure(
        "Could not start payment gateway. Please try again.",
      );
    }
  }

  Future<void> _handlePaymentSuccess(String paymentId) async {
    try {
      // 1. Update Database
      await _walletService.addMoney(_selectedAmount, paymentId: paymentId);

      // 2. Refresh UI
      await _loadBalance();

      if (mounted) {
        setState(() => _loading = false); // STOP SPINNER

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 50),
                SizedBox(height: 10),
                Text('Recharge Successful'),
              ],
            ),
            content: Text(
              '₹${_selectedAmount.toInt()} has been added to your wallet.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (widget.rechargeAmount != null) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('OK', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _handlePaymentFailure("Database update failed: $e");
    }
  }

  void _handlePaymentFailure(String error) {
    if (mounted) {
      setState(() => _loading = false); // STOP SPINNER
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'My Wallet',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // BALANCE CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade800, Colors.blue.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹ ${NumberFormat('#,##0.00').format(_balance)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                const Text(
                  'Top Up Wallet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // GRID OPTIONS
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _rechargeOptions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5,
                  ),
                  itemBuilder: (context, index) {
                    final amount = _rechargeOptions[index];
                    final isSelected = _selectedAmount == amount;

                    return InkWell(
                      onTap: () => _selectAmount(amount),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.shade50
                              : Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? Colors.blue
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+ ₹${amount.toInt()}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.blue
                                : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // CUSTOM INPUT
                const Text(
                  'Or Enter Amount',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    double? parsed = double.tryParse(val);
                    if (parsed != null) {
                      _selectedAmount = parsed;
                      if (parsed >= 500 && _errorText != null) {
                        setState(() => _errorText = null);
                      }
                    }
                  },
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    hintText: 'Minimum ₹500',
                    errorText: _errorText,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // PAY BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _initiatePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Add Money',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                      SizedBox(width: 6),
                      Text(
                        'Secure Payment by Razorpay',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // LOADING OVERLAY
          if (_loading && _balance > 0)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

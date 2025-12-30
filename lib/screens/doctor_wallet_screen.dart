// lib/screens/doctor_wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/wallet_service.dart';
import '../models/withdrawal_model.dart';
import '../widgets/custom_card.dart';
import '../widgets/primary_button.dart';

class DoctorWalletScreen extends StatefulWidget {
  const DoctorWalletScreen({super.key});

  @override
  State<DoctorWalletScreen> createState() => _DoctorWalletScreenState();
}

class _DoctorWalletScreenState extends State<DoctorWalletScreen> with SingleTickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController;
  
  double _balance = 0.0;
  bool _isLoading = true; // Start true to fetch initial data

  // Controllers for Settings
  final _upiCtrl = TextEditingController();
  final _accNumCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _upiCtrl.dispose();
    _accNumCtrl.dispose();
    _ifscCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  /// Fetches Balance and Pre-fills Saved Payout Settings
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final doc = await _firestore.collection('doctors').doc(uid).get();
      
      if (doc.exists) {
        final data = doc.data() ?? {};
        
        setState(() {
          _balance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
          
          // Pre-fill Payout Details if they exist
          if (data['upiId'] != null) {
            _upiCtrl.text = data['upiId'].toString();
          }
          
          if (data['bankDetails'] != null) {
            final bank = data['bankDetails'] as Map<String, dynamic>;
            _accNumCtrl.text = bank['accountNumber']?.toString() ?? '';
            _ifscCtrl.text = bank['ifsc']?.toString() ?? '';
            _holderCtrl.text = bank['holderName']?.toString() ?? '';
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading wallet data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestWithdrawal() async {
    if (_balance < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum withdrawal is ₹100'), backgroundColor: Colors.orange)
      );
      return;
    }

    // 1. Select Method
    final method = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Payout Method'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'upi'), 
            child: const Row(children: [Icon(Icons.qr_code), SizedBox(width: 10), Text('UPI (Fastest)')])
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'bank'), 
            child: const Row(children: [Icon(Icons.account_balance), SizedBox(width: 10), Text('Bank Transfer')])
          ),
        ],
      ),
    );

    if (method == null) return;
    if (!mounted) return;

    // 2. Confirm Amount
    final amountController = TextEditingController(text: _balance.toInt().toString());
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Funds'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Balance: ₹$_balance', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount to withdraw',
                border: OutlineInputBorder(),
                prefixText: '₹ '
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Withdraw')
          ),
        ],
      ),
    );

    if (confirm == true) {
      double amt = double.tryParse(amountController.text) ?? 0;
      
      if (amt <= 0 || amt > _balance) {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Amount'), backgroundColor: Colors.red));
         return;
      }

      setState(() => _isLoading = true);
      
      final res = await _walletService.requestWithdrawal(amt, method);
      
      await _loadData(); // Refresh balance
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message']),
          backgroundColor: res['success'] ? Colors.green : Colors.red,
        ));
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    
    try {
      // Basic validation
      bool updated = false;
      
      if (_upiCtrl.text.isNotEmpty) {
        await _walletService.updatePayoutSettings(upiId: _upiCtrl.text.trim());
        updated = true;
      }
      
      if (_accNumCtrl.text.isNotEmpty && _ifscCtrl.text.isNotEmpty) {
        await _walletService.updatePayoutSettings(bankDetails: {
          'accountNumber': _accNumCtrl.text.trim(),
          'ifsc': _ifscCtrl.text.trim().toUpperCase(),
          'holderName': _holderCtrl.text.trim(),
        });
        updated = true;
      }
      
      if (updated) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout Details Saved Successfully'), backgroundColor: Colors.green));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter details to save'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings & Wallet'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Withdraw'), Tab(text: 'Settings')],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildWithdrawTab(),
              _buildSettingsTab(),
            ],
          ),
    );
  }

  Widget _buildWithdrawTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CustomCard(
            padding: const EdgeInsets.all(24),
            color: Colors.green.shade50,
            child: Column(
              children: [
                const Text('Available Earnings', style: TextStyle(color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Text('₹${_balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(height: 16),
                PrimaryButton(label: 'Request Withdrawal', onPressed: _requestWithdrawal),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Align(alignment: Alignment.centerLeft, child: Text('Withdrawal History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          const SizedBox(height: 10),
          
          StreamBuilder<List<WithdrawalModel>>(
            stream: _walletService.getWithdrawalHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) return Text('Error: ${snapshot.error}');
              
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: Text('No withdrawal history yet.', style: TextStyle(color: Colors.grey))),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  Color statusColor;
                  IconData statusIcon;

                  switch(item.status) {
                    case 'approved': 
                      statusColor = Colors.green; 
                      statusIcon = Icons.check_circle;
                      break;
                    case 'rejected':
                      statusColor = Colors.red;
                      statusIcon = Icons.cancel;
                      break;
                    default:
                      statusColor = Colors.orange;
                      statusIcon = Icons.access_time_filled;
                  }

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(statusIcon, color: statusColor),
                      title: Text('Withdrawal: ₹${item.amount.toInt()}'),
                      subtitle: Text('${DateFormat('MMM dd, yyyy • hh:mm a').format(item.createdAt)}\nVia ${item.method.toUpperCase()}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4)
                        ),
                        child: Text(item.status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor))
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.qr_code, color: Colors.blue), SizedBox(width: 10), Text('UPI Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                const SizedBox(height: 16),
                TextField(
                  controller: _upiCtrl, 
                  decoration: const InputDecoration(
                    labelText: 'UPI ID', 
                    hintText: 'e.g. name@okhdfc',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.alternate_email)
                  )
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.account_balance, color: Colors.blue), SizedBox(width: 10), Text('Bank Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                const SizedBox(height: 16),
                TextField(
                  controller: _holderCtrl, 
                  decoration: const InputDecoration(labelText: 'Account Holder Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accNumCtrl, 
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Account Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers))
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ifscCtrl, 
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'IFSC Code', border: OutlineInputBorder(), prefixIcon: Icon(Icons.pin_drop))
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: PrimaryButton(label: 'Save Payout Details', onPressed: _saveSettings),
          ),
        ],
      ),
    );
  }
}
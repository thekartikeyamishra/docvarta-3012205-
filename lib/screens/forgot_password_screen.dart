// G:\docvartaa\lib\screens\forgot_password_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_card.dart';
import '../widgets/primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _linkSent = false;
  int _seconds = 0;
  Timer? _timer;
  static const int cooldown = 45;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds <= 1) {
        t.cancel();
        if (mounted) setState(() => _seconds = 0);
      } else {
        if (mounted) setState(() => _seconds--);
      }
    });
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter your email';
    final re = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!re.hasMatch(v.trim())) return 'Please provide a valid email';
    return null;
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (_seconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please wait $_seconds seconds before resending.')));
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim());
      setState(() => _linkSent = true);
      _startTimer();
      if (mounted) {
        await showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Reset link sent'),
          content: const Text('We have sent a reset link. If you don’t see it, check your Spam/Junk folder.'),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
        ));
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Failed to send reset link';
      if (e.code == 'user-not-found') msg = 'No account found for that email';
      if (e.code == 'invalid-email') msg = 'Please enter a valid email';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('An error occurred. Try again later.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Forgot password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
              decoration: BoxDecoration(
                color: theme.appBarTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                CircleAvatar(radius: 28, backgroundColor: Colors.white24, child: Text('DV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('DocVartaa', style: theme.appBarTheme.titleTextStyle),
                  const SizedBox(height: 4),
                  Text('Password help', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                ]),
              ]),
            ),
            const SizedBox(height: 18),
            CustomCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Reset your password', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Enter the email associated with your account and we’ll send a reset link.'),
                const SizedBox(height: 12),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    decoration: const InputDecoration(labelText: 'Email', hintText: 'you@example.com'),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: _linkSent ? 'Resend reset link' : 'Send reset link',
                  onPressed: _loading ? null : _send,
                ),
                const SizedBox(height: 10),
                if (_seconds > 0) Text('You can resend in $_seconds seconds', style: theme.textTheme.bodySmall),
                const SizedBox(height: 10),
                const Text('If the email does not appear in your inbox, check your Spam/Junk folder.'),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

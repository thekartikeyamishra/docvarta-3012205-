// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool isLogin = true;
  bool loading = false;

  void submit() async {
    setState(() => loading = true);
    final auth = context.read<AuthService>();
    final userService = context.read<UserService>();
    try {
      if (isLogin) {
        final cred = await auth.signIn(_email.text.trim(), _password.text.trim());
        // nothing else
      } else {
        final cred = await auth.signUp(_email.text.trim(), _password.text.trim());
        await userService.createBasicUserDoc(cred.user!.uid, _email.text.trim());
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Auth error')));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MedConnect')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(controller: _email, decoration: InputDecoration(labelText: 'Email')),
          TextField(controller: _password, decoration: InputDecoration(labelText: 'Password'), obscureText: true),
          SizedBox(height: 12),
          ElevatedButton(onPressed: loading ? null : submit, child: loading ? CircularProgressIndicator() : Text(isLogin ? 'Login' : 'Sign up')),
          TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? 'Create account' : 'Have account? Login')),
        ]),
      ),
    );
  }
}

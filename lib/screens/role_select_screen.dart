// lib/screens/role_select_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleSelectScreen extends StatelessWidget {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  RoleSelectScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final userService = context.read<UserService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Select Role')),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton(
            onPressed: () async {
              await userService.setRole(uid, 'patient');
              Navigator.pushReplacementNamed(context, '/patientHome');
            },
            child: const Text('I am a Patient'),
          ),
          ElevatedButton(
            onPressed: () async {
              await userService.setRole(uid, 'doctor');
              Navigator.pushReplacementNamed(context, '/doctorHome');
            },
            child: const Text('I am a Doctor'),
          ),
        ]),
      ),
    );
  }
}

/*import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// Screens
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/auth/doctor_signup.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/doctor_home_screen.dart';
import 'screens/doctor_profile_screen.dart';
import 'screens/doctor_schedule_screen.dart';
import 'screens/doctor_appointments_screen.dart';
import 'screens/patient_home_screen.dart';
import 'screens/patient_profile_screen.dart';
import 'screens/patient_search_screen.dart';
import 'screens/patient_appointments_screen.dart';
import 'screens/patient_slots_screen.dart';
import 'screens/appointment_details_screen.dart';
import 'screens/kyc_upload_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    runApp(const MyApp());
  } catch (e) {
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text("Init Error: $e")))));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocVartaa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        // Auth
        '/sign-in': (_) => const SignInScreen(),
        '/sign-up': (_) => const SignUpScreen(),
        '/doctor-signup': (_) => const DoctorSignUpScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        
        // Doctor
        '/doctorHome': (_) => const DoctorHomeScreen(),
        '/doctor-profile': (_) => const DoctorProfileScreen(),
        '/doctor-schedule': (_) => const DoctorScheduleScreen(),
        '/doctorAppointments': (_) => const DoctorAppointmentsScreen(),
        '/kyc-upload': (_) => const KycUploadScreen(),

        // Patient
        '/patientHome': (_) => const PatientHomeScreen(),
        '/patient-profile': (_) => const PatientProfileScreen(),
        '/search-doctors': (_) => const PatientSearchScreen(),
        '/patientAppointments': (_) => const PatientAppointmentsScreen(),
        '/bookSlot': (_) => const PatientSlotsScreen(),
      },
      // Handle dynamic arguments
      onGenerateRoute: (settings) {
        if (settings.name == '/appointment-details') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => AppointmentDetailsScreen(apptId: args['appointmentId']),
          );
        }
        return null;
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (!snapshot.hasData || snapshot.data == null) {
          return const SignInScreen();
        }

        return RoleResolver(user: snapshot.data!);
      },
    );
  }
}

class RoleResolver extends StatefulWidget {
  final User user;
  const RoleResolver({super.key, required this.user});

  @override
  State<RoleResolver> createState() => _RoleResolverState();
}

class _RoleResolverState extends State<RoleResolver> {
  Future<String> _getRole() async {
    try {
      // 1. Check Users Collection (Preferred)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();
      if (userDoc.exists) return userDoc.data()?['role'] ?? 'patient';

      // 2. Fallback Check (Legacy Doctors)
      final docDoc = await FirebaseFirestore.instance.collection('doctors').doc(widget.user.uid).get();
      if (docDoc.exists) return 'doctor';

      return 'patient'; // Default
    } catch (e) {
      return 'patient';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data == 'doctor' ? const DoctorHomeScreen() : const PatientHomeScreen();
      },
    );
  }
}
*/

// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ Required for Razorpay keys
import 'firebase_options.dart';

// Screens
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/auth/doctor_signup.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/doctor_home_screen.dart';
import 'screens/doctor_profile_screen.dart';
import 'screens/doctor_schedule_screen.dart';
import 'screens/doctor_appointments_screen.dart';
import 'screens/patient_home_screen.dart';
import 'screens/patient_profile_screen.dart';
import 'screens/patient_search_screen.dart';
import 'screens/patient_appointments_screen.dart';
import 'screens/patient_slots_screen.dart';
import 'screens/appointment_details_screen.dart';
import 'screens/kyc_upload_screen.dart';
import 'screens/video_call_screen.dart'; // ✅ Added if needed

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load Environment Variables (CRITICAL for Razorpay)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(
      "⚠️ Warning: .env file not found or invalid. Razorpay may not work.",
    );
  }

  // 2. Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text("Init Error: $e"))),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocVartaa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        // Auth
        '/sign-in': (_) => const SignInScreen(),
        '/sign-up': (_) => const SignUpScreen(),
        '/doctor-signup': (_) => const DoctorSignUpScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),

        // Doctor
        '/doctorHome': (_) => const DoctorHomeScreen(),
        '/doctor-profile': (_) => const DoctorProfileScreen(),
        '/doctor-schedule': (_) => const DoctorScheduleScreen(),
        '/doctorAppointments': (_) => const DoctorAppointmentsScreen(),
        '/kyc-upload': (_) => const KycUploadScreen(),

        // Patient
        '/patientHome': (_) => const PatientHomeScreen(),
        '/patient-profile': (_) => const PatientProfileScreen(),
        '/search-doctors': (_) => const PatientSearchScreen(),
        '/patientAppointments': (_) => const PatientAppointmentsScreen(),
        '/bookSlot': (_) => const PatientSlotsScreen(),
      },
      // Handle dynamic arguments
      onGenerateRoute: (settings) {
        if (settings.name == '/appointment-details') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) =>
                AppointmentDetailsScreen(apptId: args['appointmentId']),
          );
        }
        // ✅ Add handling for video call screen if needed
        if (settings.name == '/video-call') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              callId: args['callId'],
              appointmentId: args['appointmentId'],
              isDoctor: args['isDoctor'],
            ),
          );
        }
        return null;
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const SignInScreen();
        }

        return RoleResolver(user: snapshot.data!);
      },
    );
  }
}

class RoleResolver extends StatefulWidget {
  final User user;
  const RoleResolver({super.key, required this.user});

  @override
  State<RoleResolver> createState() => _RoleResolverState();
}

class _RoleResolverState extends State<RoleResolver> {
  Future<String> _getRole() async {
    try {
      // 1. Check Users Collection (Preferred)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();
      if (userDoc.exists) return userDoc.data()?['role'] ?? 'patient';

      // 2. Fallback Check (Legacy Doctors)
      final docDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.user.uid)
          .get();
      if (docDoc.exists) return 'doctor';

      return 'patient'; // Default
    } catch (e) {
      return 'patient';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == 'doctor'
            ? const DoctorHomeScreen()
            : const PatientHomeScreen();
      },
    );
  }
}

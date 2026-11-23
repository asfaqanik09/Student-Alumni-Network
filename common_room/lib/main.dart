
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';

import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/search_alumni_screen.dart';
import 'screens/incoming_requests_screen.dart';
import 'screens/admin_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase Cloud Messaging.
  await setupFirebaseMessaging();

  runApp(const CommonRoomApp());
}

// Get the Firebase device token.
Future<void> setupFirebaseMessaging() async {
  try {
    final messaging = FirebaseMessaging.instance;

    // Request notification permission.
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'Notification permission: ${settings.authorizationStatus}',
    );

    // Get the device's FCM token.
    final token = await messaging.getToken();

    if (token != null) {
      debugPrint('FCM TOKEN: $token');
    } else {
      debugPrint('FCM TOKEN: Not available yet.');
    }

    // Listen for future token changes.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('NEW FCM TOKEN: $newToken');
    });
  } catch (e) {
    debugPrint('Firebase Messaging Error: $e');
  }
}

class CommonRoomApp extends StatelessWidget {
  const CommonRoomApp({super.key});

  Future<Widget> getStartScreen() async {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getString('user_id');
    final role = prefs.getString('user_role');
    final email = prefs.getString('user_email') ?? '';

    if (userId == null || userId.isEmpty) {
      return const RegisterScreen();
    }

    if (role == 'admin') {
      return AdminDashboardScreen(email: email);
    }

    if (role == 'student') {
      return SearchAlumniScreen(userId: userId);
    }

    if (role == 'alumni') {
      return IncomingRequestsScreen(userId: userId);
    }

    return RoleSelectionScreen(userId: userId);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Common Room',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: FutureBuilder<Widget>(
        future: getStartScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return snapshot.data ?? const RegisterScreen();
        },
      ),
    );
  }
}

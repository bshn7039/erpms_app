import 'package:erpms_app/chat_list_page.dart';
import 'package:erpms_app/utils/location_helper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'home_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'signup_screen.dart';
import 'splash_screen.dart';
import 'sos_page.dart';
import 'alerts_page.dart';
import 'community_page.dart';
import 'medical_page.dart';
import 'fire_safety_page.dart';
import 'reports_page.dart';
import 'emergency_guide_page.dart';
import 'join_us_page.dart';
import 'assistant_hub_page.dart';
import 'edit_profile_screen.dart';
import 'admin_hub_page.dart';
import 'admin_incidents_page.dart';
import 'admin_volunteer_page.dart';
import 'admin_user_management_page.dart';
import 'active_assistance_page.dart';
import 'emergency_aid_guide_page.dart';
import 'chatbot_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  try {
    await Firebase.initializeApp();
    await _initFCM();
  } catch (e) {
    print("Firebase Initialization Error: $e");
  }
  runApp(const ERPMSApp());
}

Future<void> _initFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  final fcmToken = await messaging.getToken();
  print("FCM Token: $fcmToken");

  // Subscribe to district-based topic
  String? district = LocationHelper.currentDistrict;
  if (district != null && district.isNotEmpty) {
    final topic = district.replaceAll(' ', '_');
    await messaging.subscribeToTopic(topic);
    print("Subscribed to topic: $topic");
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }
  });
}

/// A wrapper that protects routes from unauthorized access.
/// If no user is logged in, it redirects to the Login screen.
class ProtectedRoute extends StatelessWidget {
  final Widget child;
  const ProtectedRoute({super.key, required this.child});

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
        if (snapshot.hasData && snapshot.data != null) {
          return child;
        }
        // Not authenticated: redirect to Login via AuthWrapper logic
        return const LoginScreen();
      },
    );
  }
}

/// Shows HomeScreen if user is logged in, LoginScreen otherwise. Used for auth persistence.
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
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class ERPMSApp extends StatelessWidget {
  const ERPMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ERPMS System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/splash':
            page = const SplashScreen();
            break;
          case '/':
            page = const AuthWrapper();
            break;
          case '/signup':
            page = const SignupScreen();
            break;
          case '/home':
            page = const ProtectedRoute(child: HomeScreen());
            break;
          case '/chat':
            page = const ProtectedRoute(child: ChatListPage());
            break;
          case '/map':
            page = const ProtectedRoute(child: MapScreen());
            break;
          case '/profile':
            page = const ProtectedRoute(child: ProfileScreen());
            break;
          case '/sos':
            page = const ProtectedRoute(child: SosPage());
            break;
          case '/alerts':
            page = const ProtectedRoute(child: AlertsPage());
            break;
          case '/community':
            page = const ProtectedRoute(child: CommunityPage());
            break;
          case '/medical':
            page = const ProtectedRoute(child: MedicalPage());
            break;
          case '/fire_safety':
            page = const ProtectedRoute(child: FireSafetyPage());
            break;
          case '/reports':
            page = const ProtectedRoute(child: ReportsPage());
            break;
          case '/emergency_guide':
            page = const ProtectedRoute(child: EmergencyGuidePage());
            break;
          case '/join_us':
            page = const ProtectedRoute(child: JoinUsPage());
            break;
          case '/assistant_hub':
            page = const ProtectedRoute(child: AssistantHubPage());
            break;
          case '/edit_profile':
            page = const ProtectedRoute(child: EditProfileScreen());
            break;
          case '/admin_hub':
            page = const ProtectedRoute(child: AdminHubPage());
            break;
          case '/admin_incidents':
            page = const ProtectedRoute(child: AdminIncidentsPage());
            break;
          case '/admin_volunteer':
            page = const ProtectedRoute(child: AdminVolunteerPage());
            break;
          case '/admin_user_management':
            page = const ProtectedRoute(child: AdminUserManagementPage());
            break;
          case '/active_assistance':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('incidentId')) {
              page = ProtectedRoute(child: ActiveAssistancePage(incidentId: args['incidentId']));
            } else {
              page = const ProtectedRoute(child: HomeScreen());
            }
            break;
          case '/emergency_aid_guide':
             // Assuming this page doesn't need constructor args but was marked as non-const
             // Or if it's obsolete, redirect to home.
            page = const ProtectedRoute(child: HomeScreen());
            break;
          case '/chatbot':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('threadId') && args.containsKey('title')) {
              page = ProtectedRoute(child: ChatbotPage(threadId: args['threadId'], title: args['title']));
            } else {
              page = const ProtectedRoute(child: HomeScreen());
            }
            break;
          default:
            page = const AuthWrapper();
        }
        return MaterialPageRoute(builder: (context) => page, settings: settings);
      },
      initialRoute: '/splash',
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'userpage.dart';
import 'admin_page.dart';
import 'welcome.dart'; // Import the welcome screen

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showWelcomeScreen = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        final databaseRef = FirebaseDatabase.instance.ref();
        databaseRef.child('users/${user.uid}/email').set(user.email);
      }
    });
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

    if (isFirstLaunch) {
      // Show welcome screen
      prefs.setBool('isFirstLaunch', false); // Set to false after showing
    } else {
      // Skip welcome screen
      setState(() {
        _showWelcomeScreen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _showWelcomeScreen
        ? ConcentricAnimationOnboarding(
            pages: pages,
            onFinished: () {
              setState(() {
                _showWelcomeScreen = false;
              });
            },
          )
        : StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return SignInScreen(
                  providers: [EmailAuthProvider()],
                  headerBuilder: (context, constraints, shrinkOffset) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.asset('assets/logo.png'),
                      ),
                    );
                  },
                  subtitleBuilder: (context, action) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: action == AuthAction.signIn
                          ? const Text('Welcome to SukanNow, please sign in!')
                          : const Text('Welcome to SukanNow, please sign up!'),
                    );
                  },
                  footerBuilder: (context, action) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'By signing in, you agree to our terms and conditions.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  },
                  actions: [
                    AuthStateChangeAction<SignedIn>((context, state) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminValidator(user: state.user!),
                        ),
                      );
                    }),
                  ],
                );
              } else {
                // User is signed in, check if they are an admin
                return AdminValidator(user: snapshot.data!);
              }
            },
          );
  }
}

// Define PageData class and pages list here (or in a separate file)
class PageData {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color bgColor;
  final Color textColor;
  final Color titleColor;
  final Color subtitleColor;

  const PageData({
    this.title,
    this.subtitle,
    this.icon,
    required this.bgColor,
    this.textColor = Colors.black,
    required this.titleColor,
    required this.subtitleColor,
  });
}

final pages = [
  PageData(
    icon: Icons.book_outlined,
    title: "Book Court In A Matter Of Seconds",
    subtitle: "Using our realtime database never been seen before",
    bgColor: const Color(0xFF212121), // Dark grey background
    textColor: Colors.white,
    titleColor: const Color(0xFF00C853), // Green accent color
    subtitleColor: Colors.grey[400]!, // Light grey for subtitle
  ),
  PageData(
    icon: Icons.people_outline,
    title: "Gym Membership For All",
    subtitle: "Becoming a member of ours have never been so easy!",
    bgColor: Colors.white, // White background
    textColor: const Color(0xFF212121), // Dark grey text
    titleColor: const Color(0xFF00C853), // Green accent color
    subtitleColor: Colors.grey[600]!, // Darker grey for subtitle
  ),
  PageData(
    icon: Icons.event_sharp,
    title: "Join Our Events!",
    subtitle: "Community driven events all weekend!",
    bgColor: const Color(0xFF00C853), // Green background
    textColor: Colors.white,
    titleColor: Colors.white,
    subtitleColor: Colors.grey[200]!, // Very light grey for subtitle
  ),
];
// Widget to validate admin user
class AdminValidator extends StatelessWidget {
  final User user;

  const AdminValidator({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DatabaseEvent>(
      future: FirebaseDatabase.instance
          .ref()
          .child('admin_users/admin_key')
          .once(),
      builder: (context, adminSnapshot) {
        if (adminSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (adminSnapshot.hasError) {
          return Center(child: Text('Error: ${adminSnapshot.error.toString()}'));
        } else if (adminSnapshot.hasData &&
            adminSnapshot.data!.snapshot.value != null) {
          final adminData =
              adminSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          if (adminData['uid'] == user.uid) {
            return const AdminPage();
          } else {
            return const HomeScreen();
          }
        } else {
          return const HomeScreen();
        }
      },
    );
  }
}
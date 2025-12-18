import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:flutter/material.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'admin_manage_availability_page.dart';
import 'admin_manage_booking_page.dart';
import 'admin_manage_event.dart';
import 'admin_membership.dart';
import 'admin_statistics.dart';
import 'userpage.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final database = FirebaseDatabase.instance.ref();
  int _pendingBookingsCount = 0;
  int _pendingMembershipRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    // Listen for user changes
    fba.FirebaseAuth.instance.userChanges().listen((user) {
      if (mounted) {
        setState(() {});
      }
    });

    // Listen for changes in the database for bookings
    database.child('badminton').onChildChanged.listen((event) => _fetchPendingBookingsCount());
    database.child('futsal').onChildChanged.listen((event) => _fetchPendingBookingsCount());
    database.child('basketball').onChildChanged.listen((event) => _fetchPendingBookingsCount());
    database.child('pingpong').onChildChanged.listen((event) => _fetchPendingBookingsCount());

    // Listen for changes in the database for membership requests
    database.child('users').onChildChanged.listen((event) => _fetchPendingMembershipRequestsCount());

    _fetchPendingBookingsCount();
    _fetchPendingMembershipRequestsCount(); // Fetch initial count
  }

  Future<void> _fetchPendingBookingsCount() async {
    final sports = ['badminton', 'futsal', 'basketball', 'pingpong'];
    int count = 0;

    for (final sport in sports) {
      final snapshot = await database.child(sport).get();
      if (snapshot.exists) {
        final bookingsData = snapshot.value as Map<dynamic, dynamic>;
        bookingsData.forEach((date, courtsData) {
          (courtsData as Map<dynamic, dynamic>).forEach((court, sessionsData) {
            if (sessionsData is Map<dynamic, dynamic>) {
              sessionsData.forEach((time, sessionData) {
                if (sessionData is Map &&
                    sessionData['status'] == 'pending') {
                  count++;
                }
              });
            } else if (sessionsData is List) {
              for (var i = 0; i < sessionsData.length; i++) {
                final sessionData = sessionsData[i];
                if (sessionData is Map &&
                    sessionData['status'] == 'pending') {
                  count++;
                }
              }
            }
          });
        });
      }
    }

    setState(() {
      _pendingBookingsCount = count;
    });
  }

  Future<void> _fetchPendingMembershipRequestsCount() async {
    int count = 0;
    final snapshot = await database.child('users').get();
    if (snapshot.exists) {
      final usersData = snapshot.value as Map<dynamic, dynamic>;
      usersData.forEach((userId, userData) {
        if (userData['membership'] != null) {
          final membershipData = userData['membership'] as Map<dynamic, dynamic>;
          membershipData.forEach((activityKey, activityData) {
            if (activityData['request'] != null) {
              count++;
            }
            // Also check for cancellation requests if needed
            if (activityData['delete'] != null) {
              count++;
            }
          });
        }
      });
    }
    setState(() {
      _pendingMembershipRequestsCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Wrap UserAvatar with GestureDetector and add nickname
            StreamBuilder<fba.User?>(
              stream: fba.FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final user = snapshot.data;
                  return Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Same functionality as the IconButton
                          Navigator.push(
                            context,
                            MaterialPageRoute<ProfileScreen>(
                              builder: (context) => ProfileScreen(
                                appBar: AppBar(
                                  title: const Text('User Profile'),
                                ),
                                actions: [
                                  SignedOutAction((context) {
                                    Navigator.pushReplacementNamed(context, '/auth-gate');
                                  })
                                ],
                              ),
                            ),
                          );
                        },
                        child: UserAvatar(
                          key: ValueKey(fba.FirebaseAuth.instance.currentUser?.photoURL),
                          auth: fba.FirebaseAuth.instance,
                          size: 30, // Adjust the size as needed
                        ),
                      ),
                      SizedBox(width: 10),
                      // Use a Column to arrange "Welcome Back" and nickname
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // Align text to the start
                        mainAxisSize: MainAxisSize.min, // Make the column as small as possible
                        children: [
                          const Text(
                            'Welcome back',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            '${user?.displayName ?? 'Guest'} (admin)',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  return const SizedBox.shrink(); // or a loading indicator
                }
              },
            ),
            GestureDetector(
              onTap: () {
                // Directly navigate to the HomeScreen (UserPage)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const HomeScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  'assets/logo.png',
                  width: 45,
                ),
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF000000), // Black
              Color(0xFF212121), // Dark gray 
            ],
            stops: [0.0, 1.0], 
          ),
        ),
        child: Column( // Wrap the Center widget with a Column
          children: [
            Expanded( // Expand to fill available space
              child: Center( 
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
              SizedBox(
                width: 200, // Adjust size as needed
                height: 200, // Adjust size as needed
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    InkWell( 
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminManageBookingPage(),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 80,
                            color: const Color.fromARGB(255, 255, 255, 255), // Example icon color
                          ),
                          const Text(
                            'Manage\nBookings',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
                          ),
                        ],
                      ),
                    ),
                    if (_pendingBookingsCount > 0)
                      Positioned(
                        right: 50,
                        top: 30,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                          child: Text(
                            '$_pendingBookingsCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Other buttons arranged in a row with icons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIconButton(
                    icon: Icons.sports_tennis,
                    label: 'Manage Court\nAvailability',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminManageAvailabilityPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  _buildIconButton(
                    icon: Icons.group,
                    label: 'Manage\nMembership',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminMembership(),
                        ),
                      );
                    },
                    counter: _pendingMembershipRequestsCount,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildIconButton(
                    icon: Icons.event,
                    label: 'Manage\nEvent',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminEvent(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  _buildIconButton(
                    icon: Icons.bar_chart,
                    label: 'Statistics',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminStats(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build icon buttons
  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    int counter = 0,
  }) {
    return SizedBox(
      width: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton( // Use IconButton instead
            onPressed: onPressed,
            icon: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: const Color.fromARGB(255, 253, 253, 253)), // Example icon color
                Text(
                  label,
                  textAlign: TextAlign.center, // Center the label text
                  style: TextStyle(color: const Color.fromARGB(255, 255, 255, 255)), // Example text color
                ),
              ],
            ),
          ),
          if (counter > 0)
            Positioned(
              right: 45,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
                child: Text(
                  '$counter',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
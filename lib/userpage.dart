import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import 'user_sports_booking.dart';
import 'user_manage_booking.dart';
import 'user_notifications.dart';
import 'user_event.dart';
import 'user_events_list.dart';
import 'user_membership.dart';
import 'admin_page.dart';
import 'user_calendar.dart';
import 'user_ewallet.dart';
import 'user_fitness.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final database = FirebaseDatabase.instance.ref();
  final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final user = FirebaseAuth.instance.currentUser;
  final logger = Logger();
  int _notificationCount = 0;
  String? _adminUid;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<dynamic, dynamic>> registeredEvents = [];
  int _walletAmount = 0;

  @override
  void initState() {
    super.initState();
    _fetchAdminUid();
    // Listen for user changes
    fba.FirebaseAuth.instance.userChanges().listen((user) {
      if (mounted) {
        setState(() {});
      }
    });
    _fetchNotificationCount();

    final userId = fba.FirebaseAuth.instance.currentUser!.uid;
    // Listen for changes in the notifications node
    database.child('users/$userId/notifications').onValue.listen((event) {
      _fetchNotificationCount();
    });
    _fetchBookings(); // Call to fetch bookings
    _loadRegisteredEvents();
    _fetchWalletAmount();
    _listenForEventsChanges();
    _listenForBookingsChanges();
    _listenForWalletChanges();
  }

  void _listenForWalletChanges() {
    final walletRef = database.child('users/$currentUserUid/wallet');
    walletRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        setState(() {
          _walletAmount = int.parse(event.snapshot.value.toString());
        });
      }
    });
  }

  void _listenForEventsChanges() {
    final eventsRef = database.child('events');
    eventsRef.onChildChanged.listen((event) {
      _loadRegisteredEvents(); // Reload events when there's a change
    });
    eventsRef.onChildAdded.listen((event) {
      _loadRegisteredEvents(); // Reload events when a new event is added
    });
    eventsRef.onChildRemoved.listen((event) {
      _loadRegisteredEvents(); // Reload events when an event is removed
    });
  }

  void _listenForBookingsChanges() {
    final sports = ['badminton', 'futsal', 'basketball', 'pingpong'];
    for (final sport in sports) {
      final bookingsRef = database.child(sport);
      bookingsRef.onChildChanged.listen((event) {
        _fetchBookings(); // Reload bookings when there's a change
      });
      bookingsRef.onChildAdded.listen((event) {
        _fetchBookings(); // Reload bookings when a new booking is added
      });
      bookingsRef.onChildRemoved.listen((event) {
        _fetchBookings(); // Reload bookings when a booking is removed
      });
    }
  }

  Future<void> _loadRegisteredEvents() async {
    if (user != null) {
      final eventSnapshot = await database.child('events').get();
      if (eventSnapshot.exists) {
        final events = (eventSnapshot.value as Map<dynamic, dynamic>).entries;
        final filteredEvents = events.where((event) {
          final registeredUsers =
              (event.value as Map<dynamic, dynamic>)['registeredUsers']
                  as Map<dynamic, dynamic>?;
          return registeredUsers != null && registeredUsers.containsKey(user!.uid);
        }).toList();
        setState(() {
          registeredEvents = filteredEvents
              .map((e) => {e.key: e.value})
              .toList();
        });
      }
    }
  }

  Future<void> _fetchBookings() async {
    final database = FirebaseDatabase.instance.ref();
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final sports = ['badminton', 'futsal', 'basketball', 'pingpong'];
    final bookings = <Map<String, dynamic>>[];
    for (final sport in sports) {
      final snapshot = await database.child(sport).get();
      if (snapshot.exists) {
        final bookingsData = snapshot.value as Map<dynamic, dynamic>;
        // Iterate through dates
        bookingsData.forEach((date, courtsData) {
          // Iterate through courts
          (courtsData as Map<dynamic, dynamic>).forEach((court, sessionsData) {
            // Iterate through sessions
            if (sessionsData is Map<dynamic, dynamic>) {
              sessionsData.forEach((time, sessionData) {
                if (sessionData is Map && sessionData['userId'] == userId) {
                  bookings.add({
                    'sport': sport,
                    'date': date,
                    'court': court,
                    'time': time,
                    'status': sessionData['status'],
                  });
                }
              });
            } else if (sessionsData is List) {
              for (var i = 0; i < sessionsData.length; i++) {
                final sessionData = sessionsData[i];
                if (sessionData is Map && sessionData['userId'] == userId) {
                  final time = (i * 30).toString(); // Assuming 30-minute intervals
                  bookings.add({
                    'sport': sport,
                    'date': date,
                    'court': court,
                    'time': time,
                    'status': sessionData['status'],
                  });
                }
              }
            }
          });
        });
      }
    }

    setState(() {
      _bookings = bookings;
    });
  }

  Future<void> _fetchAdminUid() async {
    try {
      final databaseReference = FirebaseDatabase.instance.ref();
      final snapshot =
          await databaseReference.child('admin_users/admin_key').once();
      if (snapshot.snapshot.exists) {
        final adminData = snapshot.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _adminUid = adminData['uid'] as String?; // Handle potential null here
        });
      }
    } catch (e) {
      logger.d("Error fetching admin UID: $e");
    }
  }

  Future<void> _fetchNotificationCount() async {
    final userId = fba.FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await database.child('users/$userId/notifications').get();
    if (snapshot.exists) {
      final notificationsData = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _notificationCount = notificationsData.length;
      });
    } else {
      setState(() {
        _notificationCount = 0;
      });
    }
  }

  Future<void> _fetchWalletAmount() async {
    final snapshot = await database.child('users/$currentUserUid/wallet').get();
    if (snapshot.exists) {
      setState(() {
        _walletAmount = int.parse(snapshot.value.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StreamBuilder<fba.User?>(
              stream: fba.FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final user = snapshot.data;
                  return Row(
                    children: [
                      GestureDetector(
                        onTap: () {
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
                          key: ValueKey(
                              fba.FirebaseAuth.instance.currentUser?.photoURL),
                          auth: fba.FirebaseAuth.instance,
                          size: 30,
                        ),
                      ),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Welcome back',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            user?.displayName ?? 'Guest',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Builder(
                      builder: (BuildContext context) {
                        return GestureDetector(
                          onTap: () {
                            Scaffold.of(context).openEndDrawer();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.asset(
                              'assets/logo.png',
                              width: 45,
                            ),
                          ),
                        );
                      },
                    ),
                    if (_notificationCount > 0)
                      Positioned(
                        right: 3,
                        top: 1,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                          child: Text(
                            '$_notificationCount',
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
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: <Widget>[Container()],
      ),
      endDrawer: Drawer(
        width: 250,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: Colors.deepOrange,
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: const Center(
                child: Text(
                  'Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.book_online),
              title: const Text('Court Bookings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageBookingsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Registered Events'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Events(),
                  ),
                );
              },
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notifications'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserNotifications(),
                      ),
                    );
                  },
                ),
                if (_notificationCount > 0)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      child: Text(
                        '$_notificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_adminUid?.trim() == currentUserUid.trim())
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Become Admin'),
                onTap: () {
                  // Navigate to your AdminPage
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminPage()),
                  );
                },
              ),
          ],
        ),
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
        child: Column( // Wrap the SingleChildScrollView with a Column
          children: [
            Expanded( // Expand the SingleChildScrollView to fill the available space
              child: SingleChildScrollView(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Simple wallet display
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround, // Distribute space around
                        children: [
                      GestureDetector(
                        onTap: () {
                          // Navigate to your wallet.dart page
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SukanCoin()), // Replace UserEwallet with your actual wallet page
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wallet, size: 34, color: Colors.white), // Wallet icon
                              const SizedBox(width: 8), // Spacing
                              Text(
                                '$_walletAmount',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                ' 🪙',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ],
                      ),
                      const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const FitnessPage()),
                        );
                      },
                      child: Column( // Wrap StepTracker with a Column
                        children: [
                          StepTracker(),
                        ],
                      ),
                    ),
                      const SizedBox(height: 30),
                      SizedBox(
                        height: 200,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildImageCard(
                              'assets/sports_booking.png',
                              'SPORTS',
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SportsBooking(),
                                ),
                              ),
                            ),
                            _buildImageCard(
                              'assets/sport_event.png',
                              'EVENTS',
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const UserEvent(),
                                ),
                              ),
                            ),
                            _buildImageCard(
                              'assets/membership.png',
                              'MEMBERSHIP',
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const Membership(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Calendar with styling
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2010, 10, 16),
                          lastDay: DateTime.utc(2030, 3, 14),
                          focusedDay: DateTime.now(),
                          eventLoader: (day) {
                            final formattedDay = DateFormat('yyyy-MM-dd').format(day);
                            final events = <dynamic>[];

                            // Add registered events to the calendar
                            for (var event in registeredEvents) {
                              final eventData = event.values.first as Map<dynamic, dynamic>;
                              if (eventData['date'] == formattedDay) {
                                events.add(eventData['name']);
                              }
                            }

                            // Add court bookings to the calendar
                            for (var booking in _bookings) {
                              if (booking['date'] == formattedDay) {
                                events.add(booking['sport']);
                              }
                            }

                            return events;
                          },
                          onDaySelected: (selectedDay, focusedDay) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserCalendar(
                                  selectedDay: selectedDay,
                                  bookings: _bookings,
                                  registeredEvents: registeredEvents,
                                ),
                              ),
                            );
                          },
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) {
                              if (events.isNotEmpty) {
                                return Container(
                                  margin: const EdgeInsets.only(top: 5.0), // Adjust margin as needed
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color.fromARGB(255, 255, 255, 255), // Change the color here
                                  ),
                                  width: 8.0, // Adjust size as needed
                                  height: 8.0, // Adjust size as needed
                                );
                              }
                              return null;
                            },
                          ),
                          calendarStyle: const CalendarStyle(
                            defaultTextStyle: TextStyle(color: Colors.white), // Text color
                            weekendTextStyle: TextStyle(color: Colors.white), // Weekend text color
                            todayDecoration: BoxDecoration( // Today's date decoration
                              color: Colors.deepOrange, 
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration( // Selected date decoration
                              color: Colors.blue, 
                              shape: BoxShape.circle,
                            ),
                            outsideDaysVisible: false, // Hide days outside the current month
                            cellMargin: EdgeInsets.all(5), // Add margin around each day cell
                            canMarkersOverflow: true, // Allow markers to overflow if there are many
                          ),
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            formatButtonShowsNext: false, // Hide the "next" button
                            titleCentered: true,
                            titleTextStyle: TextStyle(
                              color: Colors.white, // Header text color
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(10),
                                topRight: Radius.circular(10),
                              ),
                            ),
                            leftChevronPadding: EdgeInsets.only(left: 16), // Add padding to the left chevron
                            rightChevronPadding: EdgeInsets.only(right: 16), // Add padding to the right chevron
                            headerMargin: EdgeInsets.only(bottom: 20), // Add margin below the header
                          ),
                          daysOfWeekStyle: const DaysOfWeekStyle(
                            weekdayStyle: TextStyle(
                              color: Colors.white, // Weekday text color
                              fontWeight: FontWeight.bold,
                            ),
                            weekendStyle: TextStyle(
                              color: Colors.white, // Weekend text color
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build image cards
  Widget _buildImageCard(String imagePath, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Material( // Use Material widget
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(),
        color: Colors.transparent, 
        child: Column(
          children: [
            Image.asset(
              imagePath,
              width: 300,
              height: 150,
              fit: BoxFit.cover,
            ),
            Padding( // Add padding to the Text widget
              padding: const EdgeInsets.all(8.0),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Step tracker widget extracted from user_fitness.dart
class StepTracker extends StatefulWidget {
  const StepTracker({super.key});

  @override
  StepTrackerState createState() => StepTrackerState();
}

class StepTrackerState extends State<StepTracker> {
  late Stream<StepCount> _stepCountStream;
  late Stream<PedestrianStatus> _pedestrianStatusStream;
  String _status = '?', _steps = '?';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  void onStepCount(StepCount event) {
    setState(() {
      _steps = event.steps.toString();
    });
  }

  void onPedestrianStatusChanged(PedestrianStatus event) {
    setState(() {
      _status = event.status;
    });
  }

  void onPedestrianStatusError(error) {
    setState(() {
      _status = 'Pedestrian Status not available';
    });
  }

  void onStepCountError(error) {
    setState(() {
      _steps = 'Step Count not available';
    });
  }

  Future<bool> _checkActivityRecognitionPermission() async {
    bool granted = await Permission.activityRecognition.isGranted;
    if (!granted) {
      granted = await Permission.activityRecognition.request() ==
          PermissionStatus.granted;
    }
    return granted;
  }

  Future<void> initPlatformState() async {
    bool granted = await _checkActivityRecognitionPermission();
    if (!granted) {
      // Show a snackbar to the user
      if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Step tracker will not work without activity recognition permission.'),
      ));
      }
      return;
    }
    _pedestrianStatusStream = Pedometer.pedestrianStatusStream;
    _pedestrianStatusStream
        .listen(onPedestrianStatusChanged)
        .onError(onPedestrianStatusError);

    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(onStepCount).onError(onStepCountError);

    if (!mounted) return;
  }
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Image.asset('assets/footprint.png', height: 25, width: 25), // Your custom icon
        const SizedBox(width: 16),
        Text(
          _steps,
          style: const TextStyle(fontSize: 20,color: Colors.white),
        ),
        const SizedBox(width: 32),
        Icon(
          _status == 'walking'
              ? Icons.directions_walk
              : _status == 'stopped'
                  ? Icons.accessibility_new
                  : Icons.error,
          size: 20,
        ),
      ],
    );
  }
}
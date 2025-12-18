import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';


class AdminManageBookingPage extends StatefulWidget {
  const AdminManageBookingPage({super.key});

  @override
  State<AdminManageBookingPage> createState() => _AdminManageBookingPageState();
}

class _AdminManageBookingPageState extends State<AdminManageBookingPage> {
  final database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _pendingBookings = [];
  final _rejectReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPendingBookings();
  }

  @override
  void dispose() {
    _rejectReasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchPendingBookings() async {
    final sports = ['badminton', 'futsal', 'basketball', 'pingpong'];
    final bookings = <Map<String, dynamic>>[];

    for (final sport in sports) {
      final snapshot = await database.child(sport).get();
      if (snapshot.exists) {
        final bookingsData = snapshot.value as Map<dynamic, dynamic>;
        await Future.forEach(bookingsData.entries, (MapEntry dateEntry) async { // Use Future.forEach
          final date = dateEntry.key;
          final courtsData = dateEntry.value as Map<dynamic, dynamic>;

          await Future.forEach(courtsData.entries, (MapEntry courtEntry) async { // Use Future.forEach
            final court = courtEntry.key;
            final sessionsData = courtEntry.value;

            if (sessionsData is Map<dynamic, dynamic>) {
              await Future.forEach(sessionsData.entries, (MapEntry timeEntry) async { // Use Future.forEach
                final time = timeEntry.key;
                final sessionData = timeEntry.value;
                if (sessionData is Map && sessionData['status'] == 'pending') {
                  // Fetch the email
                  final emailSnapshot = await database.child('users/${sessionData['userId']}/email').get();
                  String userEmail = emailSnapshot.value.toString();

                  bookings.add({
                    'sport': sport,
                    'date': date,
                    'court': court,
                    'time': time,
                    'userId': sessionData['userId'],
                    'email': userEmail,
                  });
                }
              });
            } else if (sessionsData is List) {
              for (var i = 0; i < sessionsData.length; i++) {
                final sessionData = sessionsData[i];
                if (sessionData is Map && sessionData['status'] == 'pending') {
                  final time = (i * 30).toString();
                  // Fetch the email
                  final emailSnapshot = await database.child('users/${sessionData['userId']}/email').get();
                  String userEmail = emailSnapshot.value.toString();

                  bookings.add({
                    'sport': sport,
                    'date': date,
                    'court': court,
                    'time': time,
                    'userId': sessionData['userId'],
                    'email': userEmail,
                  });
                }
              }
            }
          });
        });
      }
    }

    setState(() {
      _pendingBookings = bookings;
    });
  }

  Future<void> _approveBooking(
      String sport, String date, String court, String time, String userId) async {
    try {
      // Update booking status to 'booked'
      await database
          .child(sport)
          .child(date)
          .child(court)
          .child(time)
          .update({'status': 'booked'});

      // Add notification for the user
      await database
          .child('users/$userId/notifications')
          .push()
          .set({
        'message': 'Your booking: $court, $time, $sport has been approved',
        'timestamp': ServerValue.timestamp, // Add timestamp
      });

      // Update the UI
      await _fetchPendingBookings();

      // Show a success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking approved!')),
        );
      }
    } catch (e) {
      // Show an error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving booking: $e')),
        );
      }
    }
  }

  Future<void> _rejectBooking(String sport, String date, String court, String time,
      String userId) async {
    // Store the context in a local variable
    final contextForSnackbar = context;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Booking'),
        content: TextField(
          controller: _rejectReasonController,
          decoration:
              const InputDecoration(hintText: 'Enter reason for rejection'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent, 
              shadowColor: Colors.transparent, 
              foregroundColor: Colors.orange, // Set the text color
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final reason = _rejectReasonController.text.trim();
              if (reason.isNotEmpty) {
                Navigator.pop(context); // Close the dialog first

                try {
                  // Remove booking
                  await database
                      .child(sport)
                      .child(date)
                      .child(court)
                      .child(time)
                      .remove();

                  await database
                      .child('users/$userId/notifications')
                      .push()
                      .set({
                    'message':
                        'Your booking: $court, $time, $sport has been rejected for the following reason: $reason',
                    'timestamp': ServerValue.timestamp, // Add timestamp
                  });

                  // Update the UI and show SnackBar
                  if (contextForSnackbar.mounted) {
                    setState(() {
                      _pendingBookings.removeWhere((booking) =>
                          booking['sport'] == sport &&
                          booking['date'] == date &&
                          booking['court'] == court &&
                          booking['time'] == time);
                    });

                    ScaffoldMessenger.of(contextForSnackbar).showSnackBar(
                      const SnackBar(content: Text('Booking rejected!')),
                    );
                  }
                } catch (e) {
                  // Show an error message
                  if (contextForSnackbar.mounted) {
                    ScaffoldMessenger.of(contextForSnackbar).showSnackBar(
                      SnackBar(content: Text('Error rejecting booking: $e')),
                    );
                  }
                } finally {
                  _rejectReasonController.clear();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent, 
              shadowColor: Colors.transparent, 
              foregroundColor: Colors.red, // Set the text color
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Bookings'),
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
        child: _pendingBookings.isEmpty
            ? const Center(child: Text('No pending bookings found.'))
            : Column(
                children: [
                  Expanded(
                    child: ListView.separated( 
                      itemCount: _pendingBookings.length,
                      separatorBuilder: (context, index) => const Divider(
                        color: Colors.grey, 
                        thickness: 1, 
                        indent: 16, 
                        endIndent: 16, 
                      ),
                      itemBuilder: (context, index) {
                        final booking = _pendingBookings[index];
                        final sport = booking['sport'];
                        final date = booking['date'];
                        final court = booking['court'];
                        final time = booking['time'];
                        final userId = booking['userId'];
                        final email = booking['email'];

                        return Card(
                          color: Colors.transparent,
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Email: $email', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('Sport: $sport'),
                                Text('Court: $court'),
                                Text('Date: $date'),
                                Text('Time: $time'),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _approveBooking(sport, date, court, time, userId),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent, 
                                          shadowColor: Colors.transparent, 
                                          foregroundColor: Colors.green,
                                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          side: const BorderSide(color: Colors.green, width: 2),
                                        ),
                                        child: const Text('Approve'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _rejectBooking(sport, date, court, time, userId),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent, 
                                          shadowColor: Colors.transparent, 
                                          foregroundColor: Colors.deepOrange,
                                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          side: const BorderSide(color: Colors.deepOrange, width: 2),
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
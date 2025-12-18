import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ManageBookingsPage extends StatefulWidget {
  const ManageBookingsPage({super.key});

  @override
  State<ManageBookingsPage> createState() => _ManageBookingsPageState();
}

class _ManageBookingsPageState extends State<ManageBookingsPage> {
  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
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

  Future<void> _cancelBooking(String sport, String date, String court, String time) async {
    final database = FirebaseDatabase.instance.ref();

    // Show a confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Cancellation'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent, 
              shadowColor: Colors.transparent, 
              foregroundColor: Colors.deepOrange, // Set the text color
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent, 
              shadowColor: Colors.transparent, 
              foregroundColor: Colors.deepOrange, // Set the text color
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) { // Proceed with cancellation only if confirmed
      try {
        // Remove the booking entirely
        await database
            .child(sport)
            .child(date)
            .child(court)
            .child(time)
            .remove();

        // Update the UI
        await _fetchBookings();

        // Show a success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking cancelled!')),
          );
        }
      } catch (e) {
        // Show an error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error cancelling booking: $e')),
          );
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Bookings'),
      ),
      body: Container( // Add Container for gradient
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
            child: _bookings.isEmpty
                ? const Center(child: Text('No bookings found.'))
                : Column( // Wrap the ListView.builder with a Column
                    children: [
                      Expanded( // Expand the ListView.builder to fill the available space
                        child: ListView.builder(
                          itemCount: _bookings.length,
                          itemBuilder: (context, index) {
                          final booking = _bookings[index];
                          final sport = booking['sport'];
                          final date = booking['date'];
                          final court = booking['court'];
                          final time = booking['time'];
                          final status = booking['status'];

                          // Check if the booking date has passed
                          final bookingDate = DateFormat('yyyy-MM-dd').parse(date);
                          final isPastBooking = bookingDate.isBefore(DateTime.now());

                          return ListTile(
                            title: Text('$sport: $court'),
                            subtitle: Text('Date: $date, Time: $time, Status: $status'),
                            trailing: isPastBooking
                                ? null
                                : ElevatedButton(
                                    onPressed: () => _cancelBooking(sport, date, court, time),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent, 
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.deepOrange, // Set the text color
                                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
                                    ),
                                    child: const Text('Cancel'),
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
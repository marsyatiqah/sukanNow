import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class AdminManageAvailabilityPage extends StatefulWidget {
  const AdminManageAvailabilityPage({super.key});

  @override
  State<AdminManageAvailabilityPage> createState() => _AdminManageAvailabilityPageState();
}

class _AdminManageAvailabilityPageState extends State<AdminManageAvailabilityPage> {
  final database = FirebaseDatabase.instance.ref();
  final sports = ['badminton', 'futsal', 'basketball', 'pingpong'];
  final logger = Logger();
  String? _selectedSport;
  List<DateTime> _unavailableDates = [];
  DateTime? _selectedBlockDate;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchAvailability() async {
    if (_selectedSport == null) {
      setState(() {
        _unavailableDates = [];
        _sessions = [];
      });
      return;
    }

    // Fetch unavailable dates
    final snapshot = await database.child('$_selectedSport/availability').get();
    if (snapshot.exists) {
      final availabilityData = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _unavailableDates = List<String>.from(availabilityData['dates'] ?? [])
            .map((date) => DateTime.parse(date))
            .toList();
      });
    } else {
      setState(() {
        _unavailableDates = [];
      });
    }

    // Fetch sessions for the selected date (if any)
    if (_selectedBlockDate != null) {
      await _fetchSessions();
    }
  }

  Future<void> _fetchSessions() async {
    if (_selectedSport == null || _selectedBlockDate == null) {
      setState(() {
        _sessions = [];
      });
      return;
    }

    final dateString = DateFormat('yyyy-MM-dd').format(_selectedBlockDate!);
    final courts = ['courtA', 'courtB', 'courtC', 'courtD'];
    final sessionStatus = {}; // Store the overall status for each time slot

    for (final court in courts) {
      final courtRef = database.child(_selectedSport!).child(dateString).child(court);
      final snapshot = await courtRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((time, value) {
          if (value is Map<dynamic, dynamic>) {
            final status = value['status'] as String;
            if (status == 'pending' || status == 'booked') {
              // If any court is occupied, mark the time slot as occupied
              sessionStatus[time] = 'occupied';
            } else if (!sessionStatus.containsKey(time)) {
              // Otherwise, use the current status if not already occupied
              sessionStatus[time] = status;
            }
          } else {
            final status = value as String;
            if (status == 'pending' || status == 'booked') {
              sessionStatus[time] = 'occupied';
            } else if (!sessionStatus.containsKey(time)) {
              sessionStatus[time] = status;
            }
          }
        });
      } else {
        await _createInitialSessions(courtRef, dateString);
      }
    }

    // Convert sessionStatus to the _sessions list
    setState(() {
      _sessions = sessionStatus.entries.map((e) => {'time': e.key, 'status': e.value}).toList();
      _sessions.sort((a, b) {
        final timeA = int.parse((a['time'] as String).replaceAll('-', ''));
        final timeB = int.parse((b['time'] as String).replaceAll('-', ''));
        return timeA.compareTo(timeB);
      });
    });
  }

  Future<void> _createInitialSessions(
      DatabaseReference courtRef, String dateString) async {
    final initialSessions = {};
    for (int hour = 8; hour <= 20; hour++) {
      final startTime = '${hour.toString().padLeft(2, '0')}00';
      final endTime = '${(hour + 1).toString().padLeft(2, '0')}00';
      initialSessions['$startTime-$endTime'] = 'open';
    }

    // Create sessions for all courts
    await database.child('$_selectedSport/$dateString').update({
      'courtA': initialSessions,
      'courtB': initialSessions,
      'courtC': initialSessions,
      'courtD': initialSessions,
    });
  }

  Future<void> _updateAvailability() async {
    if (_selectedSport == null) {
      return;
    }

    try {
      await database.child('$_selectedSport/availability').update({
        'dates': _unavailableDates.map((date) => date.toIso8601String()).toList(),
      });

      // Optional: Show a success message
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Availability updated!')),
      // );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating availability: $e')),
        );
      }
    }
  }

  void _toggleSessionStatus(String time) async {
    if (_selectedSport == null || _selectedBlockDate == null) {
      return;
    }

    final dateString = DateFormat('yyyy-MM-dd').format(_selectedBlockDate!);
    final courts = ['courtA', 'courtB', 'courtC', 'courtD'];

    try {
      // Check if any session is "pending" or "booked" and collect user IDs
      final affectedUsers = <String>[];
      for (final court in courts) {
        final sessionRef = database.child('$_selectedSport/$dateString/$court/$time');
        final snapshot = await sessionRef.get();
        if (snapshot.exists) {
          final data = snapshot.value;
          if (data is Map<dynamic, dynamic>) {
            final currentStatus = data['status'] as String?;
            if (currentStatus == 'pending' || currentStatus == 'booked') {
              affectedUsers.add(data['userId'] as String);
            }
          }
        }
      }

      if (affectedUsers.isNotEmpty) {
        if (mounted) {
          // Ask for confirmation before blocking
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Confirmation'),
                content: const Text('This session is currently occupied. Are you sure you want to block it?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context); // Close the dialog

                      // Proceed with blocking the session and notifying affected users
                      for (final court in courts) {
                        final sessionRef = database.child('$_selectedSport/$dateString/$court/$time');
                        await sessionRef.update({'status': 'blocked', 'userId': null});
                      }

                      // Send notifications to affected users
                      for (final userId in affectedUsers) {
                        await database
                            .child('users/$userId/notifications')
                            .push()
                            .set({
                          'message': 'We Apologize for the inconvenience but your booking:\n$time, \n$_selectedSport \n$dateString \nhas been cancelled due to court unavailability. Please do try to book another spot again.🥺',
                          'timestamp': ServerValue.timestamp,
                        });
                      }

                      await _fetchSessions(); // Refresh the UI
                    },
                    child: const Text('Block'),
                  ),
                ],
              );
            },
          );
        }
      } else {
        for (final court in courts) {
          final sessionRef = database.child('$_selectedSport/$dateString/$court/$time');
          final snapshot = await sessionRef.get();

          if (snapshot.exists) {
            final data = snapshot.value; // No type casting here

            if (data is Map<dynamic, dynamic>) {
              // Handle the case where data is a map
              final currentStatus = data['status'] as String?;

              if (currentStatus == null) {
                await sessionRef.update({'status': 'blocked'});
              } else {
                final newStatus = currentStatus == 'blocked' ? 'open' : 'blocked';
                await sessionRef.update({'status': newStatus});
              }
            } else if (data is String) {
              // Handle the case where data is a string
              final newStatus = data == 'blocked' ? 'open' : 'blocked';
              await sessionRef.update({'status': newStatus});
            } else {
              // Handle other unexpected data types if necessary
              logger.d('Unexpected data type: ${data.runtimeType}');
            }
          } else {
            // If the session doesn't exist, create it with status 'blocked'
            await sessionRef.set({'status': 'blocked'});
          }
        }
      }
      // Fetch sessions to refresh the UI
      await _fetchSessions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling session status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Availability'),
      ),
      body: Container( // Add Container here
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
        child: Column( // Wrap SingleChildScrollView with Expanded
          children: [
            Expanded( 
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sport Selection
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Select Sport',
                          labelStyle: const TextStyle(fontSize: 20, color: Colors.deepOrange), 
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.deepOrange), // Change line color
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.deepOrange), // Change focused line color
                          ),
                        ),
                        value: _selectedSport,
                        onChanged: (value) async {
                          setState(() {
                            _selectedSport = value;
                            _selectedBlockDate = null; // Reset date when sport changes
                          });
                          await _fetchAvailability();
                        },
                        items: sports.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 40),

                      // Date Availability
                      const Text('Unavailable Dates:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ..._unavailableDates.map((date) => ListTile(
                        title: Text(date.toIso8601String().substring(0, 10)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle),
                          onPressed: () async {
                            setState(() => _unavailableDates.remove(date));
                            await _updateAvailability(); // Update instantly on removal
                          },
                        ),
                      )),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (pickedDate != null && !_unavailableDates.contains(pickedDate)) {
                            setState(() => _unavailableDates.add(pickedDate));
                            await _updateAvailability(); // Update instantly on adding
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, 
                          shadowColor: Colors.transparent, 
                          foregroundColor: Colors.deepOrange, // Set the text color
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
                        ),
                        child: const Text('Add Unavailable Date',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Display Sessions
                      const Text('Unavailable Sessions:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _selectedBlockDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (pickedDate != null && pickedDate != _selectedBlockDate) {
                            setState(() {
                              _selectedBlockDate = pickedDate;
                            });
                            await _fetchSessions();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, 
                          shadowColor: Colors.transparent, 
                          foregroundColor: Colors.deepOrange, // Set the text color
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
                        ),
                        child: Text(
                          'Select Date to Manage Sessions: ${_selectedBlockDate != null ? DateFormat('yyyy-MM-dd').format(_selectedBlockDate!) : 'None'}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      ..._sessions.map((session) => ListTile(
                        title: Text(session['time']),
                        trailing: Text(
                          // Display "occupied" if status is "pending" or "booked"
                          (session['status'] == 'pending' || session['status'] == 'booked')
                              ? 'occupied'
                              : session['status'],
                          style: const TextStyle(color: Colors.deepOrange),
                        ),
                        onTap: () => _toggleSessionStatus(session['time']),
                      )),
                      const SizedBox(height: 30),
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
}
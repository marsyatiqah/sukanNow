import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'user_booking_details_page.dart';
import 'package:logging/logging.dart';

class BookingPage extends StatefulWidget {
  final String sport;
  final _logger = Logger('BookingPage');

  BookingPage({super.key, required this.sport});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  DateTime? _selectedDate;
  String? _selectedCourt;
  List<Map<String, dynamic>> _sessions = [];
  List<DateTime> _blockedDates = [];

  final _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _fetchBlockedDates();
    _fetchSessions();
  }

  Future<void> _fetchBlockedDates() async {
    final snapshot = await _database.child('${widget.sport}/availability/dates').get();
    if (snapshot.exists) {
      final data = snapshot.value as List<dynamic>;
      setState(() {
        _blockedDates = data.map((e) => DateTime.parse(e)).toList();
      });
    }
  }

   Future<void> _fetchSessions() async {
  if (_selectedDate != null && _selectedCourt != null) {
    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final courtRef = _database
        .child(widget.sport)
        .child(dateString)
        .child('court$_selectedCourt');

    final snapshot = await courtRef.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _sessions = data.entries.map((e) {
          if (e.value is Map<dynamic, dynamic>) {  // Check if the value is a Map
            final value = e.value as Map<dynamic, dynamic>;
            return {
              'time': e.key,
              'status': value['status'] as String, // Explicitly cast to String
              'userId': value['userId'] as String?, // Explicitly cast to String?
            };
          } else {
            return {
              'time': e.key,
              'status': e.value as String, // Explicitly cast to String
              'userId': null, 
            };
          }
        }).toList();

        _sessions.sort((a, b) {
          final timeA = int.parse((a['time'] as String).replaceAll('-', ''));
          final timeB = int.parse((b['time'] as String).replaceAll('-', ''));
          return timeA.compareTo(timeB);
        });
      });
    } else {
      await _createInitialSessions(courtRef, dateString);
      _fetchSessions();
    }
  }
}

  Future<void> _createInitialSessions(
      DatabaseReference courtRef, String dateString) async {
    final initialSessions = {};
    for (int hour = 8; hour <= 20; hour++) {
      final startTime = '${hour.toString().padLeft(2, '0')}00';
      final endTime = '${(hour + 1).toString().padLeft(2, '0')}00';
      initialSessions['$startTime-$endTime'] = 'open';
    }

    await courtRef.set(initialSessions);
    widget._logger.info('Created initial sessions for $dateString');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book ${widget.sport} Court'),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Picker
              ElevatedButton(
                onPressed: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate!,
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 8)),
                    selectableDayPredicate: (DateTime date) {
                      return !_blockedDates.contains(date);
                    },
                  );
                  if (pickedDate != null && pickedDate != _selectedDate) {
                    setState(() {
                      _selectedDate = pickedDate;
                    });
                    _fetchSessions();
                  }
                },
                style: ElevatedButton.styleFrom(
                  alignment: Alignment.centerLeft, 
                  padding: const EdgeInsets.only(left: 0.0), 
                  backgroundColor: Colors.transparent, 
                  shadowColor: Colors.transparent, 
                  foregroundColor: Colors.deepOrange, // Set the text color
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
                ),
                child: Text(
                  'Select Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
                  style: TextStyle(fontSize: 20.0),
                ),
              ),
              const SizedBox(height: 16),

              // Court Selector
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Select Court',
                  labelStyle: TextStyle(color: Colors.deepOrange), // Change the label color
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.deepOrange), // Change the line color
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.deepOrange), // Change the focused line color
                  ),
                ),
                value: _selectedCourt,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCourt = newValue;
                  });
                  _fetchSessions();
                },
                items: ['A', 'B', 'C', 'D'].map((court) {
                  return DropdownMenuItem(
                    value: court,
                    child: Text('Court $court'),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Session List
              Expanded(
                child: _sessions.isEmpty
                    ? const Center(
                        child: Text('No sessions available.'),
                      )
                    : ListView.builder(
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          final isInteractable = session['status'] == 'open'; // Only open sessions are interactable

                          return ListTile(
                            title: Text(session['time']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(session['status']), // Display the status
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: isInteractable
                                      ? () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  BookingDetailsPage(
                                                sport: widget.sport,
                                                date: _selectedDate!,
                                                court: _selectedCourt!,
                                                time: session['time'],
                                                onBookingConfirmed: () {
                                                  _fetchSessions();
                                                },
                                              ),
                                            ),
                                          );
                                        }
                                      : null,
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
      ),
    ),
    );
  }
}
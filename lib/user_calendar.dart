import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class UserCalendar extends StatefulWidget {
  final DateTime selectedDay;
  final List<Map<String, dynamic>> bookings;
  final List<Map<dynamic, dynamic>> registeredEvents;

  const UserCalendar({
    super.key,
    required this.selectedDay,
    required this.bookings,
    required this.registeredEvents,
  });

  @override
  State<UserCalendar> createState() => _UserCalendarState();
}

class _UserCalendarState extends State<UserCalendar> {
  late final ValueNotifier<List<dynamic>> _selectedEvents;
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  final logger = Logger();

  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.selectedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_focusedDay));
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final formattedDay = DateFormat('yyyy-MM-dd').format(day);
    final events = <dynamic>[];

    for (var event in widget.registeredEvents) {
      final eventData = event.values.first as Map<dynamic, dynamic>;
      if (eventData['date'] == formattedDay) {
        // Include all event details
        events.add(eventData); 
      }
    }

    for (var booking in widget.bookings) {
      if (booking['date'] == formattedDay) {
        // Include all booking details
        events.add(booking);
      }
    }

    return events;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_focusedDay, selectedDay)) {
      setState(() {
        _focusedDay = focusedDay;
      });

      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
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
        child: Column(
          children: [
            const SizedBox(height: 30),
            TableCalendar<dynamic>(
              firstDay: DateTime.utc(2010, 10, 16),
              lastDay: DateTime.utc(2030, 3, 14),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              eventLoader: _getEventsForDay,
              selectedDayPredicate: (day) {
                return isSameDay(_focusedDay, day);
              },
              onDaySelected: _onDaySelected,
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isNotEmpty) {
                    return Container(
                      margin: const EdgeInsets.only(top: 5.0), // Adjust margin as needed
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white, // Change the color here
                      ),
                      width: 8.0, // Adjust size as needed
                      height: 8.0, // Adjust size as needed
                    );
                  }
                  return null; // Return null if there are no events
                },
              ),
              calendarStyle: const CalendarStyle(
                defaultTextStyle: TextStyle(color: Colors.white),
                weekendTextStyle: TextStyle(color: Colors.white),
                todayDecoration: BoxDecoration(
                  color: Colors.deepOrange,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                outsideDaysVisible: false,
                cellMargin: EdgeInsets.all(5),
                canMarkersOverflow: true,
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                formatButtonShowsNext: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepOrange,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                leftChevronPadding: EdgeInsets.only(left: 16),
                rightChevronPadding: EdgeInsets.only(right: 16),
                headerMargin: EdgeInsets.only(bottom: 20),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                weekendStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            Expanded(
              child: ValueListenableBuilder<List<dynamic>>(
                valueListenable: _selectedEvents,
                builder: (context, value, _) {
                  return ListView.builder(
                    itemCount: value.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: ListTile(
                          onTap: () => logger.d('${value[index]}'),
                          title: Text(
                            '${value[index]['name'] ?? value[index]['sport']} - ${value[index]['location'] ?? value[index]['court']} - ${value[index]['time']}',
                          ),
                        ),
                      );
                    },
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
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class AdminStats extends StatefulWidget {
  const AdminStats({super.key});

  @override
  State<AdminStats> createState() => _AdminStatsState();
}

class _AdminStatsState extends State<AdminStats> {
  final database = FirebaseDatabase.instance.ref();
  int _totalUsers = 0;
  int _totalBookings = 0;
  int _totalMemberships = 0; 
  final Map<String, int> _eventParticipation = {};
  final Map<String, Map<String, int>> _membershipParticipation = {};
  final Map<String, Map<String, int>> _sportsParticipation = {};

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    // Fetch total users
    final usersSnapshot = await database.child('users').get();
    if (usersSnapshot.exists) {
      _totalUsers = (usersSnapshot.value as Map<dynamic, dynamic>).length;
    }

    // Fetch total bookings and sports participation
    final sports = ['badminton', 'futsal', 'basketball', 'pingpong'];

    // Fetch sports participation with this week/last week breakdown
    final now = DateTime.now();
    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeekEnd = thisWeekStart.add(const Duration(days: 6));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = thisWeekEnd.subtract(const Duration(days: 7));

    for (final sport in sports) {
      // Initialize counts for this week and last week to 0
      _sportsParticipation[sport] = {
        'This Week': 0,
        'Last Week': 0,
      };
      // Fetch unavailable dates for the sport
      final unavailableDatesSnapshot = await database.child('$sport/availability/dates').get();
      List<DateTime> unavailableDates = [];
      if (unavailableDatesSnapshot.exists) {
        unavailableDates = List<String>.from(unavailableDatesSnapshot.value as List<dynamic>)
            .map((date) => DateTime.parse(date))
            .toList();
      }

      final sportSnapshot = await database.child(sport).get();
      if (sportSnapshot.exists) {
        final sportData = sportSnapshot.value as Map<dynamic, dynamic>;
        sportData.forEach((date, courtsData) {
          // Skip this date if it's in the unavailable dates list
          if (unavailableDates.any((unavailableDate) => unavailableDate.toIso8601String().substring(0, 10) == date)) {
            return;
          }

          // Calculate total bookings correctly
          int thisWeekCount = 0;
          int lastWeekCount = 0;
          (courtsData as Map<dynamic, dynamic>).forEach((court, sessionsData) {
            if (sessionsData is Map<dynamic, dynamic>) {
              thisWeekCount += sessionsData.values.where((sessionData) => sessionData
              is Map && sessionData['status'] == 'booked' && DateTime.parse(date).isAfter(thisWeekStart) && DateTime.parse(date).isBefore(thisWeekEnd)).length;
              lastWeekCount += sessionsData.values.where((sessionData) => sessionData is Map && sessionData['status'] == 'booked' &&
                  DateTime.parse(date).isAfter(lastWeekStart) && DateTime.parse(date).isBefore(lastWeekEnd)).length;
              _totalBookings += sessionsData.values.where((sessionData) => sessionData is Map && sessionData['status'] == 'booked').length;
            } else if (sessionsData is List) {
              thisWeekCount += sessionsData.where((sessionData) => sessionData is Map && sessionData['status'] == 'booked' && DateTime.parse(date).isAfter(thisWeekStart) &&
                  DateTime.parse(date).isBefore(thisWeekEnd)).length;
              lastWeekCount += sessionsData.where((sessionData) => sessionData is Map && sessionData['status'] == 'booked' && DateTime.parse(date).isAfter(lastWeekStart) && DateTime.parse(date).isBefore(lastWeekEnd)).length;
              _totalBookings += sessionsData.where((sessionData) => sessionData is Map && sessionData['status'] == 'booked').length;
            }
          });
          _sportsParticipation[sport]!['This Week'] = _sportsParticipation[sport]!['This Week']! + thisWeekCount;
          _sportsParticipation[sport]!['Last Week'] = _sportsParticipation[sport]!['Last Week']! + lastWeekCount;
        });
      }
    }

    // Fetch event participation
    final eventsSnapshot = await database.child('events').get();
    if (eventsSnapshot.exists) {
      final eventsData = eventsSnapshot.value as Map<dynamic, dynamic>;
      eventsData.forEach((eventId, eventData) {
        if (eventData is Map<dynamic, dynamic>) {
          final registeredUsers = eventData['registeredUsers'] as Map<dynamic, dynamic>?;
          if (registeredUsers != null) {
            _eventParticipation.update(eventData['name'], (value) => value + registeredUsers.length,
                ifAbsent: () => registeredUsers.length);
          }
        }
      });
    }

    // Fetch membership participation with pass type breakdown and calculate total memberships
    if (usersSnapshot.exists) {
      final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
      for (var entry in usersData.entries) {
        final userData = entry.value;
        if (userData is Map<dynamic, dynamic> && userData['membership'] != null) {
          final membershipData = userData['membership'] as Map<dynamic, dynamic>;
          for (var sport in ['gym', 'swimming']) {
            if (membershipData[sport] != null && membershipData[sport]['status'] == 'active') {
              final type = membershipData[sport]['type'];
              _membershipParticipation.putIfAbsent(sport, () => {});
              _membershipParticipation[sport]!.update(type, (value) => value + 1, ifAbsent: () => 1);
              _totalMemberships++; // Increment total memberships
            }
          }
        }
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
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
        child: Column( // Add Column to wrap the SingleChildScrollView
          children: [
            Expanded( // Expand the SingleChildScrollView to fill available space
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround, // Distribute icons evenly
                      children: [
                        Column(
                          children: [
                            Icon(Icons.person,),
                            Text('$_totalUsers'),
                            Text('Total Users'),
                          ],
                        ),
                        Column(
                          children: [
                            Icon(Icons.book),
                            Text('$_totalBookings'),
                            Text('Total Bookings'),
                          ],
                        ),
                        Column(
                          children: [
                            Icon(Icons.card_membership),
                            Text('$_totalMemberships'), // Display total memberships
                            Text('Memberships'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text('Sports Bookings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    _buildSportsParticipationList(_sportsParticipation),
                    const Divider(),
                    const SizedBox(height: 20),
                    const Text('Event Participation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    _buildParticipationList(_eventParticipation),
                    const Divider(),
                    const Text('Membership', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    _buildMembershipParticipationList(_membershipParticipation),
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
  Widget _buildParticipationList(Map<String, int> participationData) {
    return SfCircularChart(
      title: ChartTitle(text: 'Events Overview'),
      legend: Legend(isVisible: true), // Add this line to enable the legend
      series: <PieSeries<MapEntry<String, int>, String>>[
        PieSeries<MapEntry<String, int>, String>(
          explode: true,
          explodeIndex: 0,
          dataSource: participationData.entries.toList(),
          xValueMapper: (MapEntry<String, int> entry, _) => entry.key,
          yValueMapper: (MapEntry<String, int> entry, _) => entry.value,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _buildSportsParticipationList(Map<String, Map<String, int>> participationData) {
    return SfCartesianChart(
      title: ChartTitle(text: 'Sports Overview'),
      primaryXAxis: CategoryAxis(),
      legend: Legend(isVisible: true),
      series: participationData.entries.map((entry) {
        return ColumnSeries<MapEntry<String, int>, String>(
          name: entry.key,
          dataSource: entry.value.entries.toList(),
          xValueMapper: (MapEntry<String, int> entry, _) => entry.key,
          yValueMapper: (MapEntry<String, int> entry, _) => entry.value,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        );
      }).toList(),
    );
  }

  Widget _buildMembershipParticipationList(Map<String, Map<String, int>> participationData) {
    return SfCartesianChart(
      title: ChartTitle(text: 'Membership Overview'),
      primaryXAxis: CategoryAxis(),
      legend: Legend(isVisible: true),
      series: participationData.entries.map((entry) {
        return ColumnSeries<MapEntry<String, int>, String>(
          name: entry.key,
          dataSource: entry.value.entries.toList(),
          xValueMapper: (MapEntry<String, int> entry, _) => entry.key,
          yValueMapper: (MapEntry<String, int> entry, _) => entry.value,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        );
      }).toList(),
    );
  }
}
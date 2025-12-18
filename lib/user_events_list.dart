import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class Events extends StatefulWidget {
  const Events({super.key});

  @override
  State<Events> createState() => _EventsState();
}

class _EventsState extends State<Events> {
  final database = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser;
  List<Map<dynamic, dynamic>> registeredEvents = [];

  @override
  void initState() {
    super.initState();
    _loadRegisteredEvents();
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

  Future<void> _unregisterForEvent(String eventKey, Map<dynamic, dynamic> event) async {
    if (user != null) {
      final eventName = event['name'];
      final requireWallet = event['requireWallet'] as bool;
      final walletAmount = event['walletAmount'] as int;

      // Show confirmation dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Unregistration'),
          content: Text(
            'Are you sure you want to unregister from $eventName?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent, 
                shadowColor: Colors.transparent, 
                foregroundColor: Colors.deepOrange, // Set the text color
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Store the context for use after await
                final contextForSnackbar = context;

                // Close the dialog before proceeding
                Navigator.of(context).pop();

                // Unregister for the event
                await database
                    .child('events/$eventKey/registeredUsers/${user!.uid}')
                    .remove();

                // Update participant count
                final eventRef = database.child('events/$eventKey');
                await eventRef.update({'participants': ServerValue.increment(-1)});

                // Define userWalletRef here so it's accessible later
                final userWalletRef = database.child('users/${user!.uid}/wallet');

                if (requireWallet) {
                  // Refund SukanCoin to user's wallet
                  final userWalletSnapshot = await userWalletRef.get();
                  if (userWalletSnapshot.exists) {
                    final userWalletAmount =
                        int.parse(userWalletSnapshot.value.toString());
                    await userWalletRef.set(userWalletAmount + walletAmount);

                    // Get updated balance
                    final updatedWalletSnapshot = await userWalletRef.get();
                    final updatedBalance =
                        int.parse(updatedWalletSnapshot.value.toString());

                    // Use the stored contextForSnackbar
                    if (contextForSnackbar.mounted) {
                      ScaffoldMessenger.of(contextForSnackbar).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Unregistered from $eventName successfully! Your new balance is $updatedBalance 🪙.'),
                        ),
                      );
                    }
                  }
                } else {
                  // No SukanCoin refund needed, show the standard message
                  if (contextForSnackbar.mounted) {
                    ScaffoldMessenger.of(contextForSnackbar).showSnackBar(
                      SnackBar(
                        content: Text('Unregistered from $eventName successfully!'),
                      ),
                    );
                  }
                }

                // Reload registered events
                _loadRegisteredEvents();
              },
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registered Events'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF000000),
              Color(0xFF212121),
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: registeredEvents.length,
                itemBuilder: (context, index) {
                  final eventKey = registeredEvents[index].keys.first;
                  final event =
                      registeredEvents[index][eventKey] as Map<dynamic, dynamic>;

                  // Check if the event date has passed
                  final eventDate = DateTime.parse(event['date']);
                  final now = DateTime.now();
                  final isPastEvent = eventDate.isBefore(now);

                  return Card(
                    color: Colors.transparent,
                    elevation: 0,
                    child: ListTile(
                      leading: event['imageUrl'] != null
                          ? SizedBox(
                              width: 50,
                              height: 50,
                              child: Image.network(event['imageUrl'], fit: BoxFit.cover),
                            )
                          : const Icon(Icons.event),
                      title: Text(event['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event['date']),
                          if (event['time'] != null) Text(event['time']),
                          if (event['location'] != null) Text(event['location']),
                        ],
                      ),
                      trailing: !isPastEvent
                          ? ElevatedButton(
                              onPressed: () => _unregisterForEvent(eventKey, event),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.deepOrange,
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              child: const Text('Unregister'),
                            )
                          : null, 
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
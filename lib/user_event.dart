import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class UserEvent extends StatefulWidget {
  const UserEvent({super.key});

  @override
  State<UserEvent> createState() => _UserEventState();
}

class _UserEventState extends State<UserEvent> {
  final database = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser;
  List<Map<dynamic, dynamic>> events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final eventSnapshot = await database.child('events').get();
    if (eventSnapshot.exists) {
      setState(() {
        events = (eventSnapshot.value as Map<dynamic, dynamic>)
            .entries
            .map((e) => {e.key: e.value})
            .toList();
      });
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Events'),
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
      child: Column( // Wrap the ListView with a Column
        children: [
          Expanded( // Expand the ListView to fill the available space
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final eventKey = events[index].keys.first;
                final event = events[index][eventKey] as Map<dynamic, dynamic>;

                return Card(
                  color: Colors.transparent,
                  elevation: 0,
                  child: ListTile(
                    leading: event['imageUrl'] != null
                        ? SizedBox(
                            width: 100, // Set the width of the image
                            height: 100, // Set the height of the image
                            child: Image.network(event['imageUrl'], fit: BoxFit.cover),
                          )
                        : const Icon(Icons.event),
                    title: Text(event['name']),
                    subtitle: Text(event['date']),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventDetails(
                              event: event,
                              eventKey: eventKey,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent, 
                        shadowColor: Colors.transparent, 
                        foregroundColor: Colors.deepOrange, // Set the text color
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Customize padding
                      ),
                      child: const Text('View Details'),
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

class EventDetails extends StatefulWidget {
  final Map<dynamic, dynamic> event;
  final String eventKey;

  const EventDetails({
    super.key,
    required this.event,
    required this.eventKey,
  });

  @override
  State<EventDetails> createState() => _EventDetailsState();
}

class _EventDetailsState extends State<EventDetails> {
  final database = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser;
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    _checkRegistrationStatus();
  }

  Future<void> _checkRegistrationStatus() async {
    final snapshot = await database
        .child('events/${widget.eventKey}/registeredUsers/${user?.uid}')
        .get();
    setState(() {
      _isRegistered = snapshot.exists;
    });
  }

  Future<void> _registerForEvent() async {
    if (user != null) {
      final eventName = widget.event['name'];
      final requireWallet = widget.event['requireWallet'] as bool;
      final walletAmount = widget.event['walletAmount'] as int;
      
      if (requireWallet) {
        final userWalletRef = database.child('users/${user!.uid}/wallet');
        final userWalletSnapshot = await userWalletRef.get();

        if (userWalletSnapshot.exists) {
          final userWalletAmount =
              int.parse(userWalletSnapshot.value.toString());
              
          if (userWalletAmount >= walletAmount) {
            // Show confirmation dialog
            if (mounted) { 
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Confirm Registration'),
                content: Text(
                  'You are about to register for $eventName. This will deduct $walletAmount SukanCoin from your wallet. Do you want to proceed?',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      // Store the context for use after await
                      final contextForSnackbar = context;

                      // Close the dialog before proceeding
                      Navigator.of(context).pop();
                      try {
                        // Deduct SukanCoin from user's wallet
                        await userWalletRef.set(userWalletAmount - walletAmount);
                        // Register for the event
                        await database
                            .child(
                                'events/${widget.eventKey}/registeredUsers/${user!.uid}')
                            .set(true);
                        // Update participant count
                        final eventRef =
                            database.child('events/${widget.eventKey}');
                        await eventRef.update({
                          'participants': ServerValue.increment(1)
                        });

                        // Get updated balance
                        final updatedWalletSnapshot =
                            await userWalletRef.get();
                        final updatedBalance = int.parse(
                            updatedWalletSnapshot.value.toString());

                        // Use the stored contextForSnackbar
                        if (contextForSnackbar.mounted) {
                          ScaffoldMessenger.of(contextForSnackbar)
                              .showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Registered for $eventName successfully! Your new balance is $updatedBalance 🪙.'),
                            ),
                          );
                        }
                        setState(() {
                          _isRegistered = true;
                        });
                      } catch (e) {
                        // Handle any errors that occur during the process
                        if (contextForSnackbar.mounted) {
                          ScaffoldMessenger.of(contextForSnackbar)
                              .showSnackBar(
                            SnackBar(
                              content: Text('Error registering for event: $e'),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Insufficient SukanCoin balance.'),
                ),
              );
            }
          }
        }
      } else {
        // No SukanCoin required, register directly
        await database
            .child('events/${widget.eventKey}/registeredUsers/${user!.uid}')
            .set(true);
        // Update participant count
        final eventRef = database.child('events/${widget.eventKey}');
        await eventRef.update({'participants': ServerValue.increment(1)});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registered for $eventName successfully!'),
            ),
          );
        }
        setState(() {
          _isRegistered = true;
        });
      }
    }
  }

  Future<void> _unregisterForEvent() async {
    if (user != null) {
      final eventName = widget.event['name'];
      final requireWallet = widget.event['requireWallet'] as bool;
      final walletAmount = widget.event['walletAmount'] as int;

      // Store the context for use after await
      final contextForSnackbar = context;

      // Unregister for the event
      await database
          .child('events/${widget.eventKey}/registeredUsers/${user!.uid}')
          .remove();
      // Update participant count
      final eventRef = database.child('events/${widget.eventKey}');
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

      setState(() {
        _isRegistered = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event['name']),
        actions: [
          if (_isRegistered)
            ElevatedButton(
              onPressed: _unregisterForEvent,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, 
                  shadowColor: Colors.transparent, 
                  foregroundColor: Colors.deepOrange, // Set the text color
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
                ),
              child: const Text('Unregister'),
            )
          else
            ElevatedButton(
              onPressed: _registerForEvent,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, 
                  shadowColor: Colors.transparent, 
                  foregroundColor: Colors.deepOrange, // Set the text color
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
                ),
              child: const Text('Register'),
            ),
        ],
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
        child: Column( // Wrap the SingleChildScrollView with a Column
          children: [
            Expanded( // Expand the SingleChildScrollView to fill the available space
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.event['imageUrl'] != null)
                        SizedBox(
                          height: 200, // Set a fixed height for the image
                          child: Image.network(widget.event['imageUrl'],
                              width: double.infinity, fit: BoxFit.cover),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Description:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(widget.event['description']),
                      const SizedBox(height: 16),
                      Text(
                        'Date:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (widget.event['date'] != null) Text(widget.event['date']),
                      const SizedBox(height: 16),
                      Text(
                        'Time:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (widget.event['time'] != null) Text(widget.event['time']),
                      const SizedBox(height: 16),
                      Text(
                        'Location:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(widget.event['location']),
                      const SizedBox(height: 16),
                      Text(
                        'Max Participants:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(widget.event['maxParticipants'].toString()),
                      if (widget.event['requireWallet']) ...[
                        const SizedBox(height: 16),
                        Text(
                          '🪙 Required:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(widget.event['walletAmount'].toString()),
                      ],
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
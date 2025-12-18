import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class Membership extends StatefulWidget {
  const Membership({super.key});

  @override
  State<Membership> createState() => _MembershipState();
}

class _MembershipState extends State<Membership> {
  final database = FirebaseDatabase.instance.ref();
  final userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Membership'),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Select Activity',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _images.length,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Navigate to the MembershipDetails page when an activity is selected
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MembershipDetails(
                              activity: _images[index]['subtitle']!,
                            ),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 500,
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                _images[index]['image']!,
                                height: 200,
                                width: 400,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      _images[index]['subtitle']!,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  final List<Map<String, String>> _images = const [
    {
      'image': 'assets/Gym.png',
      'subtitle': 'Gym',
    },
    {
      'image': 'assets/Swimming.png',
      'subtitle': 'Swimming',
    },
  ];
}

// New class/page to handle membership details
class MembershipDetails extends StatefulWidget {
  final String activity;

  const MembershipDetails({super.key, required this.activity});

  @override
  State<MembershipDetails> createState() => _MembershipDetailsState();
}

class _MembershipDetailsState extends State<MembershipDetails> {
  final database = FirebaseDatabase.instance.ref();
  final userId = FirebaseAuth.instance.currentUser!.uid;
  String? _membershipType;
  int _walletAmount = 0;
  bool _hasMembership = false;
  bool _isExpired = false; // Track if membership is expired
  bool _showRenewalButton = false; // Track whether to show the renew button

  @override
  void initState() {
    super.initState();
    _fetchWalletAmount();
    _checkMembershipStatus();

    // Add a listener to monitor changes in membership status
    String activityKey = widget.activity.toLowerCase().replaceAll(' ', '_');
    database.child('users/$userId/membership/$activityKey').onValue.listen((event) {
      _updateMembershipStatus(event.snapshot);
    });
  }

  // Function to update membership status and check for expiry
  void _updateMembershipStatus(DataSnapshot snapshot) {
    setState(() {
      _hasMembership = snapshot.exists && snapshot.child('status').value == 'active';
      if (_hasMembership) {
        DateTime expiryDate = DateTime.parse(snapshot.child('expiryDate').value.toString());
        _isExpired = expiryDate.isBefore(DateTime.now());
        // Show renew button only if membership exists and is expired
        _showRenewalButton = _isExpired; 
      } else {
        _isExpired = false; // Reset if no membership
        _showRenewalButton = false; // Hide renew button if no membership
      }
    });
  }

  
  Future<void> _checkMembershipStatus() async {
    String activityKey = widget.activity.toLowerCase().replaceAll(' ', '_');
    final snapshot = await database.child('users/$userId/membership/$activityKey').get();
    _updateMembershipStatus(snapshot); 
  }

  Future<void> _fetchWalletAmount() async {
    final snapshot = await database.child('users/$userId/wallet').get();
    if (snapshot.exists) {
      setState(() {
        _walletAmount = int.parse(snapshot.value.toString());
      });
    }
  }

  Future<void> _purchaseMembership(int cost) async {
    String activityKey = widget.activity.toLowerCase().replaceAll(' ', '_');
    final requestSnapshot = await database.child('users/$userId/membership/$activityKey/request').get();

    if (requestSnapshot.exists) {
      // Membership request already exists, show message
      if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your membership request is already underway.')),
      );
      }
      return; // Do not proceed with the purchase
    }

    if (_walletAmount >= cost) {
      try {
        // Set membership request
        await database.child('users/$userId/membership/$activityKey').update({
          'request': _membershipType,
        });

        // Send notification about membership request with timestamp
        await database.child('users/$userId/notifications').push().set({
          'message': 'Your $_membershipType membership request for ${widget.activity} is underway.',
          'timestamp': ServerValue.timestamp, // Add timestamp
        });

        // Show success message
        if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Membership request submitted successfully!')),
        );
        }
      } catch (e) {
        // Show error message
        if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting membership request: $e')),
        );
        }
      }
    } else {
      // Show insufficient funds message
      if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient funds.')),
      );
      }
    }
  }

  Future<void> _cancelMembership() async {
    String activityKey = widget.activity.toLowerCase().replaceAll(' ', '_');
    final deleteSnapshot = await database.child('users/$userId/membership/$activityKey/delete').get();

    if (deleteSnapshot.exists) {
      // Cancellation request already exists, show message
      if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cancellation request is already underway.')),
      );
      }
      return; // Do not proceed with the cancellation
    }

    try {
      // Set cancellation request
      await database.child('users/$userId/membership/$activityKey').update({
        'delete': true,
      });

      // Send notification about cancellation request with timestamp
      await database.child('users/$userId/notifications').push().set({
        'message': 'Your ${widget.activity} membership cancellation request is underway.',
        'timestamp': ServerValue.timestamp, // Add timestamp
      });

      // Show success message
      if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Membership cancellation request submitted successfully!')),
      );
      }
    } catch (e) {
      // Show error message
      if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting cancellation request: $e')),
      );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.activity} Membership'),
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Choose Membership for ${widget.activity}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Show membership options ONLY if NO membership or AFTER renew button is clicked
              if (!_hasMembership || (_isExpired && !_showRenewalButton))
                Column(
                  children: [
                    if (widget.activity == 'Swimming') ...[
                      _buildMembershipButton('Day Pass', 2),
                      _buildMembershipButton('Week Pass', 10),
                      _buildMembershipButton('Month Pass', 30),
                      _buildMembershipButton('Year Pass', 100),
                    ] else ...[ 
                      _buildMembershipButton('Day Pass', 5),
                      _buildMembershipButton('Week Pass', 30),
                      _buildMembershipButton('Month Pass', 90),
                      _buildMembershipButton('Year Pass', 500),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),

              // Conditionally render cancel button or renew button
              if (_hasMembership && !_isExpired) // Show cancel button if active
                ElevatedButton(
                  onPressed: _cancelMembership,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent, 
                    shadowColor: Colors.transparent, 
                    foregroundColor: Colors.deepOrange, // Set the text color
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
                  ),
                  child: const Text('Cancel Membership'),
                )
              else if (_showRenewalButton) // Show renew button if expired AND _showRenewalButton is true
                ElevatedButton(
                  onPressed: () {
                    // This effectively re-shows the membership options
                    setState(() { 
                      _showRenewalButton = false; 
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent, 
                    shadowColor: Colors.transparent, 
                    foregroundColor: Colors.deepOrange, // Set the text color
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
                  ),
                  child: const Text('Renew Membership'),
                ),

              const SizedBox(height: 20),

              // View Membership Status Button
              if (_hasMembership)
                ElevatedButton(
                  onPressed: () async {
                    // Get the membership for the current activity
                    String activityKey =widget.activity.toLowerCase().replaceAll(' ', '_');
                    final snapshot = await database.child('users/$userId/membership/$activityKey').get();

                    // Build a string to display membership details
                    String membershipDetails = "";

                    if (snapshot.exists) {
                      Map<dynamic, dynamic>? membershipData = snapshot.value as Map?;
                      String type = membershipData?['type'] ?? 'No membership';
                      String status = membershipData?['status'] ?? '';
                      String expiryDateString = membershipData?['expiryDate'] ?? '';

                      // Format expiry date
                      DateTime expiryDate = DateTime.parse(expiryDateString);
                      String formattedExpiryDate = "${expiryDate.day}-${expiryDate.month}-${expiryDate.year}";

                      // Build the decorated message
                      membershipDetails += "Membership: $type\n";
                      if (expiryDate.isBefore(DateTime.now())) {
                        membershipDetails += "Status: Expired ❌\n"; // Force expired status
                      } else {
                        membershipDetails += "Status: ${status == 'active' ? 'Active ✅' : 'Expired ❌'}\n";
                      }
                      membershipDetails += "Expires: $formattedExpiryDate"; 
                    } else {
                      membershipDetails = "You do not have an active ${widget.activity} membership.";
                    }

                    // Show membership details in a dialog
                    if (mounted) { // Add this check
                      showDialog(
                        // ignore: use_build_context_synchronously
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Membership Status'),
                          content: Text(membershipDetails),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent, 
                                shadowColor: Colors.transparent, 
                                foregroundColor: Colors.deepOrange, // Set the text color
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
                              ),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent, 
                    shadowColor: Colors.transparent, 
                    foregroundColor: Colors.deepOrange, // Set the text color
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
                  ),
                  child: const Text('View Membership Status'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipButton(String type, int cost) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _membershipType = type;
        });
        _purchaseMembership(cost);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent, 
        shadowColor: Colors.transparent, 
        foregroundColor: Colors.yellow, // Set the text color
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
      ),
      child: Text('$type - $cost 🪙'),
    );
  }
}
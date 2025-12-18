import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class AdminMembership extends StatefulWidget {
  const AdminMembership({super.key});

  @override
  State<AdminMembership> createState() => _AdminMembershipState();
}

class _AdminMembershipState extends State<AdminMembership> {
  final database = FirebaseDatabase.instance.ref();
  final logger = Logger();

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Manage Membership'),
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
          Expanded( 
            child: FutureBuilder(
              future: _loadRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No pending requests.'));
                } else {
                  List<Widget> requestWidgets = snapshot.data!;
                  return ListView(
                    children: requestWidgets.map((widget) {
                      return Column(
                        children: [
                          widget,
                          const Divider(
                            height: 2, 
                            thickness: 1,
                            color: Colors.grey, 
                            indent: 16, 
                            endIndent: 16, 
                          ), 
                        ],
                      );
                    }).toList(),
                  );
                }
              }
            ),
          ),
        ],
      ),
    ),
  );
}

  // Function to load requests asynchronously
  Future<List<Widget>> _loadRequests() async {
    List<Widget> requestWidgets = [];

    final usersSnapshot = await database.child('users').get(); // Await the get() call
    if (usersSnapshot.exists) {
      Map<dynamic, dynamic> usersData = usersSnapshot.value as Map<dynamic, dynamic>;

      for (var userEntry in usersData.entries) {
        final userId = userEntry.key;
        final userData = userEntry.value;

        if (userData['membership'] != null) {
          Map<dynamic, dynamic> membershipData = userData['membership'];

          final emailSnapshot = await database.child('users/$userId/email').get();
          String userEmail = emailSnapshot.exists ? emailSnapshot.value.toString() : "Unknown Email";

          for (var activityEntry in membershipData.entries) {
            final activityKey = activityEntry.key;
            final activityData = activityEntry.value;

            logger.d("Checking user: $userEmail, activity: $activityKey");

            if (activityData['request'] != null) {
              logger.d("Found request: ${activityData['request']}");
              String membershipType = activityData['request'];
              requestWidgets.add(
                _buildRequestTile(userId, userEmail, activityKey, membershipType),
              );
            }
            if (activityData['delete'] != null) {
              logger.d("Found cancellation request");
              requestWidgets.add(
                _buildCancellationTile(userId, userEmail, activityKey, activityData['type']),
              );
            }
          }
        }
      }
    }
    return requestWidgets;
  }
  
Widget _buildRequestTile(String userId, String userEmail, String activityKey, String membershipType) {
  return ListTile(
    title: Text('$userEmail - ${activityKey.replaceAll('_', ' ')} - $membershipType'),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 105, // Set desired width here
          child: OutlinedButton(
            onPressed: () => _approveMembership(userId, activityKey, membershipType),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green, width: 2.0), // Adjust width here
            ),
            child: const Text('Approve'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 105, // Same width as the Approve button
          child: OutlinedButton(
            onPressed: () => _rejectMembership(userId, activityKey, membershipType),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.deepOrange, 
              side: const BorderSide(color: Colors.deepOrange, width: 2.0), // Adjust width here
            ),
            child: const Text('Reject'),
          ),
        ),
      ],
    ),
  );
}

Widget _buildCancellationTile(String userId, String userEmail, String activityKey, String membershipType) {
  return ListTile(
    title: Text('$userEmail - ${activityKey.replaceAll('_', ' ')} - Cancellation'),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 105, // Set desired width here
          child: OutlinedButton(
            onPressed: () => _approveCancellation(userId, activityKey, membershipType),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green, width: 2.0),
            ),
            child: const Text('Approve'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 105, // Same width as the Approve button
          child: OutlinedButton(
            onPressed: () => _rejectCancellation(userId, activityKey),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.deepOrange, 
              side: const BorderSide(color: Colors.deepOrange, width: 2.0),
            ),
            child: const Text('Reject'),
          ),
        ),
      ],
    ),
  );
}

  Future<void> _approveMembership(String userId, String activityKey, String membershipType) async {
    try {
      // Calculate expiry date
      DateTime now = DateTime.now();
      DateTime expiryDate;
      switch (membershipType) {
        case 'Day Pass':
          expiryDate = now.add(const Duration(days: 1));
          break;
        case 'Week Pass':
          expiryDate = now.add(const Duration(days: 7));
          break;
        case 'Month Pass':
          expiryDate = now.add(const Duration(days: 30));
          break;
        case 'Year Pass':
          expiryDate = now.add(const Duration(days: 365));
          break;
        default:
          expiryDate = now;
      }

      // Update membership status with expiry date
      await database.child('users/$userId/membership/$activityKey').update({
        'type': membershipType,
        'status': 'active',
        'expiryDate': expiryDate.toIso8601String(),
      });

      // Deduct cost from wallet
      int cost = _getMembershipCost(activityKey, membershipType);

      final walletSnapshot = await database.child('users/$userId/wallet').get();
      if (walletSnapshot.exists) {
        int walletAmount = int.parse(walletSnapshot.value.toString());
        if (walletAmount >= cost) {
          await database.child('users/$userId/wallet').set(walletAmount - cost);
        }
      }

      // Remove the request key
      await database.child('users/$userId/membership/$activityKey/request').remove();

      // Send notification about membership approval with cost information and timestamp
      await database.child('users/$userId/notifications').push().set({
        'message': 'Your $membershipType membership request for ${activityKey.replaceAll('_', ' ')} has been approved! $cost 🪙 has been deducted from your wallet.',
        'timestamp': ServerValue.timestamp,
      });

      // Show success message
      if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membership request approved successfully!')),
      );
      }
      setState(() {});
    } catch (e) {
      // Show error message
      if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving membership request: $e')),
      );
      }
    }
  }

  Future<void> _rejectMembership(String userId, String activityKey, String membershipType) async {
    final rejectionReasonController = TextEditingController();
    String? reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          cursorColor: Colors.deepOrange,
          controller: rejectionReasonController,
          decoration: const InputDecoration(
            hintText: 'Enter reason for rejection (optional)',
            focusedBorder: UnderlineInputBorder( // Customize the focused border
              borderSide: BorderSide(color: Colors.orange), // Set the line color to blue
            ),
            enabledBorder: UnderlineInputBorder( // Customize the unfocused border
              borderSide: BorderSide(color: Colors.deepOrange), // Set the unfocused line color to grey
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent, 
              shadowColor: Colors.transparent, 
              foregroundColor: Colors.orange, // Set the text color
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, rejectionReasonController.text.trim()),
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
    
    // If the reason is null, the admin canceled the rejection.
    if (reason == null) {
      return; // Exit the function early
    }

    try {
      // Remove the request key
      await database.child('users/$userId/membership/$activityKey/request').remove();

      // Send notification about membership rejection with reason
      await database.child('users/$userId/notifications').push().set({
        'message':'Your $membershipType membership request for ${activityKey.replaceAll('_', ' ')} has been rejected. Reason: $reason',
        'timestamp': ServerValue.timestamp,
      });

      // Show success message
      if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membership request rejected successfully!')),
      );
      }
      setState(() {});
    } catch (e) {
      // Show error message
      if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting membership request: $e')),
      );
      }
    }
  }

  Future<void> _approveCancellation(String userId, String activityKey, String membershipType) async {
    try {
      int membershipCost = _getMembershipCost(activityKey, membershipType);
      int refundAmount = membershipCost ~/ 2;
      // Update wallet amount with refund
      final walletSnapshot = await database.child('users/$userId/wallet').get();
      if (walletSnapshot.exists) {
        int walletAmount = int.parse(walletSnapshot.value.toString());
        await database.child('users/$userId/wallet').set(walletAmount + refundAmount);
      }

      // Remove membership status
      await database.child('users/$userId/membership/$activityKey').remove();

      // Send notification about cancellation approval and refund with timestamp
      await database.child('users/$userId/notifications').push().set({
        'message': 'Your ${activityKey.replaceAll('_', ' ')} membership cancellation request has been approved. You have been refunded $refundAmount 🪙.',
        'timestamp': ServerValue.timestamp,
      });

      // Show success message
      if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membership cancellation request approved successfully!')),
      );
      }
      setState(() {});
    } catch (e) {
      // Show error message
      if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving cancellation request: $e')),
      );
      }
    }
  }

  Future<void> _rejectCancellation(String userId, String activityKey) async {
    final rejectionReasonController = TextEditingController();
    String? reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: rejectionReasonController,
          cursorColor: Colors.deepOrange,
          decoration: const InputDecoration(
            hintText: 'Enter reason for rejection (optional)',
            focusedBorder: UnderlineInputBorder( // Customize the focused border
              borderSide: BorderSide(color: Colors.orange), // Set the line color to blue
            ),
            enabledBorder: UnderlineInputBorder( // Customize the unfocused border
              borderSide: BorderSide(color: Colors.deepOrange), // Set the unfocused line color to grey
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent, 
              shadowColor: Colors.transparent, 
              foregroundColor: Colors.orange, // Set the text color
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, rejectionReasonController.text.trim()),
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
    
    // If the reason is null, the admin canceled the rejection.
    if (reason == null) {
      return; // Exit the function early
    }

    try {
      // Remove the delete key
      await database.child('users/$userId/membership/$activityKey/delete').remove();

      // Send notification about cancellation rejection with reason
      await database.child('users/$userId/notifications').push().set({
        'message': 'Your ${activityKey.replaceAll('_', ' ')} membership cancellation request has been rejected. Reason: $reason',
        'timestamp': ServerValue.timestamp,
      });

      // Show success message
      if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membership cancellation request rejected successfully!')),
      );
      }
      setState(() {});
    } catch (e) {
      // Show error message
      if (mounted) { 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting cancellation request: $e')),
      );
      }
    }
  }

  // Helper function to get membership cost based on activity and type
  int _getMembershipCost(String activityKey, String membershipType) {
    if (activityKey.toLowerCase() == 'swimming') {
      switch (membershipType) {
        case 'Day Pass': return 2;
        case 'Week Pass': return 10;
        case 'Month Pass': return 30;
        case 'Year Pass': return 100;
        default: return 0;
      }
    } else { // For other activities (Gym, etc.)
      switch (membershipType) {
        case 'Day Pass': return 5;
        case 'Week Pass': return 30;
        case 'Month Pass': return 90;
        case 'Year Pass': return 500;
        default: return 0;
      }
    }
  }
}
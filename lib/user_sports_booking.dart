import 'package:flutter/material.dart';
import 'user_booking_page.dart';

class SportsBooking extends StatelessWidget {
  const SportsBooking({super.key});

  final List<Map<String, String>> _images = const [
    {
      'image': 'assets/badminton.jpg',
      'subtitle': 'Badminton',
    },
    {
      'image': 'assets/futsal.jpg',
      'subtitle': 'Futsal',
    },
    {
      'image': 'assets/pingpong.jpg',
      'subtitle': 'Ping Pong',
    },
    {
      'image': 'assets/basketball.jpg',
      'subtitle': 'Basketball',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sports Booking'),
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
            'Available Activities',
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
                        Widget destinationScreen;
                        switch (_images[index]['subtitle']) {
                          case 'Badminton':
                            destinationScreen = BookingPage(sport: 'badminton');
                            break;
                          case 'Futsal':
                            destinationScreen = BookingPage(sport: 'futsal');
                            break;
                          case 'Ping Pong':
                            destinationScreen = BookingPage(sport: 'pingpong');
                            break;
                          case 'Basketball':
                            destinationScreen = BookingPage(sport: 'basketball');
                            break;
                          default:
                            destinationScreen = const SportsBooking(); 
                            break;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => destinationScreen,
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
}
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:logger/logger.dart';

class FitnessPage extends StatefulWidget {
  const FitnessPage({super.key});

  @override
  State<FitnessPage> createState() => _FitnessPageState();
}

class _FitnessPageState extends State<FitnessPage> {
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  final logger = Logger();
  late Stream<StepCount> _stepCountStream;
  int _todaySteps = 0;
  int _goal = 8000; // Initial goal
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadGoal();
    _loadTodaySteps();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(onStepCount).onError(onStepCountError);

    if (!mounted) return;
  }

  void onStepCount(StepCount event) {
    _todaySteps = event.steps;
    _updateProgress();
    _saveTodaySteps();
  }

  void onStepCountError(error) {
    // Handle step count error
    logger.d('Step Count not available');
  }

  Future<void> _loadGoal() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final snapshot = await _database.child('users/$userId/goal').get();
      if (snapshot.exists) {
        setState(() {
          _goal = int.parse(snapshot.value.toString());
          _updateProgress();
        });
      }
    }
  }

  Future<void> _loadTodaySteps() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final snapshot = await _database.child('users/$userId/todaystep').get();
      if (snapshot.exists) {
        setState(() {
          _todaySteps = int.parse(snapshot.value.toString());
          _updateProgress();
        });
      }
    }
  }

  void _saveTodaySteps() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _database.child('users/$userId/todaystep').set(_todaySteps);
    }
  }

  void _updateProgress() {
    setState(() {
      _progress = _todaySteps / _goal;
    });
  }

  Future<void> _setGoal(int newGoal) async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _database.child('users/$userId/goal').set(newGoal);
      setState(() {
        _goal = newGoal;
        _updateProgress();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness Tracker'),
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
              SfRadialGauge(
                axes: <RadialAxis>[
                  RadialAxis(
                    minimum: 0,
                    maximum: 1,
                    showLabels: false,
                    showTicks: false,
                    startAngle: 270,
                    endAngle: 270,
                    radiusFactor: 0.8,
                    axisLineStyle: const AxisLineStyle(
                      thickness: 0.2,
                      color: Color.fromARGB(52, 255, 86, 34),
                      thicknessUnit: GaugeSizeUnit.factor,
                      cornerStyle: CornerStyle.bothCurve,
                    ),
                    pointers: <GaugePointer>[
                      RangePointer(
                        value: _progress,
                        cornerStyle: CornerStyle.bothCurve,
                        width: 0.2,
                        sizeUnit: GaugeSizeUnit.factor,
                        color: Colors.deepOrange,
                      ),
                      MarkerPointer(
                        value: _progress,
                        markerHeight: 20,
                        markerWidth: 20,
                        markerType: MarkerType.circle,
                        color: Colors.deepOrange,
                      ),
                    ],
                    annotations: <GaugeAnnotation>[
                      GaugeAnnotation(
                        widget: Text(
                          _todaySteps.toString(),
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                        angle: 90,
                        positionFactor: 0.5,
                      ),
                      GaugeAnnotation(
                        widget: Text(
                          'Goal: $_goal step',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Color.fromARGB(255, 255, 255, 255),
                          ),
                        ),
                        angle: 90,
                        positionFactor: 1.3,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  final newGoalController = TextEditingController();
                  final newGoal = await showDialog<int>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Set Daily Goal'),
                        content: TextField(
                          controller: newGoalController,
                          cursorColor: Colors.deepOrange,
                          decoration: const InputDecoration(
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.deepOrange), // Change line color
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.orange), // Change focused line color
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
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
                            onPressed: () {
                              final newGoal = int.tryParse(newGoalController.text);
                              Navigator.pop(context, newGoal);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent, 
                              shadowColor: Colors.transparent, 
                              foregroundColor: Colors.deepOrange, // Set the text color
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
                            ),
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                  if (newGoal != null) {
                    _setGoal(newGoal);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, 
                  shadowColor: Colors.transparent, 
                  foregroundColor: Colors.deepOrange, // Set the text color
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Customize text style
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Customize padding
                  side: const BorderSide(color: Colors.deepOrange, width: 2), // Add a border
                ),
                child: const Text('Set Goal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GoalDialog extends StatefulWidget {
  final int initialGoal;

  const GoalDialog({super.key, required this.initialGoal});

  @override
  State<GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<GoalDialog> {
  late int _goal;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _goal = widget.initialGoal;
    _controller = TextEditingController(text: _goal.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Daily Goal'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        onChanged: (value) {
          setState(() {
            _goal = int.tryParse(value) ?? widget.initialGoal;
          });
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, _goal);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
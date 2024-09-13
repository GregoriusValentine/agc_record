import 'package:flutter/material.dart';

class AgcResultsWidget extends StatefulWidget {
  const AgcResultsWidget({super.key});

  @override
  State<AgcResultsWidget> createState() => _AgcResultsWidgetState();
}

class _AgcResultsWidgetState extends State<AgcResultsWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Text(
          'AGC Results',
          style: TextStyle(
            color: Colors.white
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

class resultWidget extends StatefulWidget {
  const resultWidget({super.key});

  @override
  State<resultWidget> createState() => _resultWidgetState();
}

class _resultWidgetState extends State<resultWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Text(
          'Result',
          style: TextStyle(
            color: Colors.white
          ),
        ),
      ),
    );
  }
}
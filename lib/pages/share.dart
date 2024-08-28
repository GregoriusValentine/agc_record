import 'package:flutter/material.dart';

class shareWidget extends StatefulWidget {
  const shareWidget({super.key});

  @override
  State<shareWidget> createState() => _shareWidgetState();
}

class _shareWidgetState extends State<shareWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Text(
          'Share',
          style: TextStyle(
            color: Colors.white
          ),
        ),
      ),
    );
  }
}
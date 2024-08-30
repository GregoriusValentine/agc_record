import 'dart:async';
import 'package:flutter/material.dart';

class recordWidget extends StatefulWidget {
  const recordWidget({super.key});

  @override
  State<recordWidget> createState() => _recordWidgetState();
}

class _recordWidgetState extends State<recordWidget> {
  late Timer _timer;
  int _seconds = 0;
  bool _isRecording = false;
  bool _isPaused = false;

  @override
  void dispose() {
    if (_timer.isActive) _timer.cancel();
    super.dispose();
  }

  void _startOrStopRecording() {
    if (_isRecording) {
      _timer.cancel();
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _seconds = 0; // Reset timer
      });
    } else {
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (!_isPaused) {
          setState(() {
            _seconds++;
          });
        }
      });
      
      setState(() {
        _isRecording = true;
      });
    }
  }

  void _pauseOrResumeRecording() {
    if (_isRecording) {
      setState(() {
        _isPaused = !_isPaused;
      });
    }
    if(_seconds == 0){
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (!_isPaused) {
          setState(() {
            _seconds++;
          });
        }
      });
      
      setState(() {
        _isRecording = true;
      });
    }
  }

  void _resetTimer() {
    if (_timer.isActive) _timer.cancel(); // Menghentikan timer jika aktif
    setState(() {
      _seconds = 0;
      _isPaused = true;
    });
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Text(
          'Record',
          style: TextStyle(
            color: Colors.white
          ),
        ),
      ),
      body: Container(
        child: Center(
          child: Container(
            height: height * 0.50,
            child: Column(
              children: [
                Container(
                  child: Container(
                    height: height*0.18,
                    child: Center(
                      child: Container(
                        child: Text(
                          _formatTime(_seconds),
                          style: TextStyle(
                            fontSize: 50,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: height * 0.14,
                  child: Center(
                    child: Column(
                      children: [
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Ink(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color.fromARGB(255, 250, 103, 66),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.6),
                                      spreadRadius: 0,
                                      blurRadius: 6,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    _isRecording
                                        ? (_isPaused
                                            ? Icons.play_arrow
                                            : Icons.pause)
                                        : Icons.mic_rounded,
                                    size: 50,
                                    color: Colors.black,
                                  ),
                                  onPressed: _isRecording
                                      ? _pauseOrResumeRecording
                                      : _startOrStopRecording,
                                ),
                              ),
                              SizedBox(width: 20),
                              if (_isRecording)
                              Row(
                                children: [
                                  Ink(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color.fromARGB(255, 250, 103, 66),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.6),
                                          spreadRadius: 0,
                                          blurRadius: 6,
                                          offset: Offset(1, 1),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.stop,
                                        size: 50,
                                        color: Colors.black,
                                      ),
                                      onPressed: _startOrStopRecording,
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  Ink(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color.fromARGB(255, 250, 103, 66),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.6),
                                          spreadRadius: 0,
                                          blurRadius: 6,
                                          offset: Offset(1, 1),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.refresh,
                                        size: 50,
                                        color: Colors.black,
                                      ),
                                      onPressed: _resetTimer,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  child: Container(
                    height: height*0.18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
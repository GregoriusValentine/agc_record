import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

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

  late final RecorderController _recorderController;

  @override
  void initState() {
    super.initState();
    _recorderController = RecorderController();
    // Jika ada metode inisialisasi lain, panggil di sini
  }

  @override
  void dispose() {
    _recorderController.dispose();
    if (_timer.isActive) _timer.cancel();
    super.dispose();
  }

  void _startOrStopRecording() async {
    if (_isRecording) {
      await _recorderController.stop();
      _timer.cancel();
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _seconds = 0; // Reset timer
      });
    } else {
      await _recorderController.record();
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

  void _pauseOrResumeRecording() async {
    if (_isRecording && !_isPaused) {
      await _recorderController.pause();
      setState(() {
        _isPaused = true;
      });
    }else if(_isRecording && _isPaused){
      await _recorderController.record();
      setState(() {
        _isPaused = false;
      });
    }
    if (!_timer.isActive) {
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (!_isPaused) {
          setState(() {
            _seconds++;
          });
        }
      });
    }
  }

  void _resetTimer() async {
    await _recorderController.stop();
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
    var width = MediaQuery.of(context).size.width;
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
                              Column(
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
                                  Text(
                                    _isRecording
                                        ? (_isPaused ? 'Resume' : 'Pause')
                                        : 'Start',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              SizedBox(width: 20),
                              if (_isRecording)
                              Row(
                                children: [
                                  Column(
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
                                      Text('Stop',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      )
                                    ],
                                  ),
                                  SizedBox(width: 20),
                                  Column(
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
                                            Icons.refresh,
                                            size: 50,
                                            color: Colors.black,
                                          ),
                                          onPressed: _resetTimer,
                                        ),
                                      ),
                                      Text('Reset',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      )
                                    ],
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
                    height: height*0.15,
                    child: Center(
                      child: Container(
                        width: width * 0.4,
                        height: height * 0.1,
                        // color: Colors.grey,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque, 
                            onHorizontalDragUpdate: (details) {
                              double positionX = details.localPosition.dx;
                              double widthLimit = width * 0.4; 
                              double heightLimit = height * 0.4; 
                            },
                            child: AudioWaveforms(
                              enableGesture: false,
                              size: Size(width * 0.8, height * 0.1),
                              recorderController: _recorderController,
                              waveStyle: WaveStyle(
                                waveColor: Colors.deepPurple,
                                showMiddleLine: false,
                              ),
                            ),
                          ),
                        ), 
                      ),
                    ), 
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
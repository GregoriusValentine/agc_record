import 'dart:async';
import 'dart:io';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class RecordingWidget extends StatefulWidget {
  const RecordingWidget({super.key});
  @override
  State<RecordingWidget> createState() => _RecordingWidgetState();
}

class _RecordingWidgetState extends State<RecordingWidget> {
  late final RecorderController _recorderController;
  late final AudioRecorder audioRecord;
  String audioPath = '';
  Timer? _timer;
  int _seconds = 0;
  bool _isRecording = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _recorderController = RecorderController();
    audioRecord = AudioRecorder();
    _requestPermissions();
  }

  @override
  void dispose() {
    _recorderController.dispose();
    audioRecord.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<String> _getIncrementedFileName(Directory recordingsDir) async {
    final List<FileSystemEntity> files = recordingsDir.listSync();
    int maxIndex = 0;

    for (var file in files) {
        final fileName = file.path.split('/').last;
        final match = RegExp(r'Recording-(\d+)_Time-').firstMatch(fileName);
        if (match != null) {
          final index = int.parse(match.group(1)!);
          if (index > maxIndex) {
            maxIndex = index;
          }
        }
      }
    return 'Recording-${maxIndex + 1}';
  }

  void _showRecordingSavedFlushbar(BuildContext context) {
    Flushbar(
      title: "Saved Recordings",
      message: "Your recording has been successfully saved.",
      duration: const Duration(seconds: 1),
      backgroundColor: Colors.green,
      icon: const Icon(
        Icons.check_circle,
        color: Colors.white,
      ),
      flushbarPosition: FlushbarPosition.TOP,
      flushbarStyle: FlushbarStyle.FLOATING,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
    ).show(context);
  }

  void _pauseOrResumeRecording() async {
    if (_isRecording && !_isPaused) {
      await _recorderController.pause();
      await audioRecord.pause();
      setState(() {
        _isPaused = true;
      });
    }else if(_isRecording && _isPaused){
      await _recorderController.record();
      await audioRecord.resume(); // Resume the audio recording
      setState(() {
        _isPaused = false;
      });
    }
  }

   Future<void> _startOrStopRecording() async {
    var logger = Logger();
    try{
      if(await audioRecord.hasPermission()){
        if (_isRecording) {
          await _recorderController.stop();
          String? path = await audioRecord.stop();
          _timer?.cancel();
          setState(() {
            _isRecording = false;
            _isPaused = false;
            _seconds = 0;
            audioPath = path!;
          });
          if (mounted) {
            _showRecordingSavedFlushbar(context);
          }
        } else {
          if(await Permission.storage.request().isGranted){
            final directory = await getExternalStorageDirectory();
            final recordingsDir = Directory('${directory!.path}/MyRecordings');
            if (!await recordingsDir.exists()) {
              await recordingsDir.create(recursive: true);
              logger.d("Directory created: ${recordingsDir.path}");
            } else {
              logger.d("Directory already exists: ${recordingsDir.path}");
            }
            final now = DateTime.now();
            final formattedTime = DateFormat('hh-mm-ss-a').format(now);
            final incrementedFileName = await _getIncrementedFileName(recordingsDir);
            final audioPath = '${recordingsDir.path}/${incrementedFileName}_Time-$formattedTime.wav';
            logger.d("Recording path: $audioPath");
            _timer = Timer.periodic(
              const Duration(seconds: 1),
              (timer) {
                if (!_isPaused) {
                  setState(() {
                    _seconds++;
                  });
              }
            });
            await _recorderController.record();
            await audioRecord.start(const RecordConfig(), path: audioPath);
            setState(() {
              _isRecording = true;
            });
          }
        }
      }
    }catch(e){
      logger.e("Error log", error: e);
    }
  }

  Future<void> _cancelRecording() async {
    var logger = Logger();
    try {
      if (_isRecording) {
        await _recorderController.stop();
        await audioRecord.stop();
        _timer?.cancel();
        
        setState(() {
          _isRecording = false;
          _isPaused = false;
          _seconds = 0;
        });

        await audioRecord.cancel();

        if (mounted) {
          Flushbar(
            title: "Recording Canceled",
            message: "Your recording has been canceled and is not saved.",
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.red,
            icon: const Icon(
              Icons.cancel,
              color: Colors.white,
            ),
            flushbarPosition: FlushbarPosition.TOP,
            flushbarStyle: FlushbarStyle.FLOATING,
            margin: const EdgeInsets.all(8),
            borderRadius: BorderRadius.circular(8),
          ).show(context);
        }
      }
    } catch (e) {
      logger.e("Error log", error: e);
    }
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
    var isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: const Text(
          'Recording',
          style: TextStyle(
            color: Colors.white
          ),
        ),
      ),
      body: Center(
        child: SizedBox(
          height: isLandscape ? height * 0.8 : height * 0.5,
          child: Column(
            children: [
              SizedBox(
                child: SizedBox(
                  height: isLandscape ? height * 0.2 : height * 0.18,
                  child: Center(
                    child: SizedBox(
                      child: Text(
                        _formatTime(_seconds),
                        style: TextStyle(
                          fontSize: isLandscape ? 40 : 50,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: isLandscape ? height * 0.2 : height * 0.14,
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
                                    color: const Color.fromARGB(255, 250, 103, 66),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.6),
                                        spreadRadius: 0,
                                        blurRadius: 6,
                                        offset: const Offset(1, 1),
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
                                      size: isLandscape ? 40 : 50,
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
                                  style: TextStyle(
                                    fontSize: isLandscape ? 14 : 16, 
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            if (_isRecording)
                            Row(
                              children: [
                                Column(
                                  children: [
                                    Ink(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.green,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.6),
                                            spreadRadius: 0,
                                            blurRadius: 6,
                                            offset: const Offset(1, 1),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.check_rounded,
                                          size: isLandscape ? 40 : 50,
                                          color: Colors.black,
                                        ),
                                        onPressed: _startOrStopRecording,
                                      ),
                                    ),
                                    Text(
                                      'Saved',
                                      style: TextStyle(
                                        fontSize: isLandscape ? 14 : 16, 
                                        fontWeight: FontWeight.bold
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(width: 20),
                                Column(
                                  children: [
                                    Ink(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.red,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.6),
                                            spreadRadius: 0,
                                            blurRadius: 6,
                                            offset: const Offset(1, 1),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.clear_rounded,
                                          size: isLandscape ? 40 : 50,
                                          color: Colors.black,
                                        ),
                                        onPressed: _cancelRecording,
                                      ),
                                    ),
                                    Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontSize: isLandscape ? 14 : 16, 
                                        fontWeight: FontWeight.bold
                                      ),
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
              SizedBox(
                child: SizedBox(
                  height: isLandscape ? height * 0.18 : height * 0.15,
                  child: Center(
                    child: SizedBox(
                      width: width * 0.4,
                      height: height * 0.1,
                      // color: Colors.grey,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque, 
                          onHorizontalDragUpdate: (details) { 
                            details.localPosition.dx;
                          },
                          child: AudioWaveforms(
                            enableGesture: false,
                            size: Size(width * 0.8, height * 0.1),
                            recorderController: _recorderController,
                            waveStyle: const WaveStyle(
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
    );
  }
}
import 'dart:io';

import 'package:agc_record/pages/fade_page_route.dart';
import 'package:agc_record/widgets/bottom_nav.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class RecordingResultsWidget extends StatefulWidget {
  final int selectedIndex;
  const RecordingResultsWidget({super.key, required this.selectedIndex});

  @override
  State<RecordingResultsWidget> createState() => _RecordingResultsWidgetState();
}

class _RecordingResultsWidgetState extends State<RecordingResultsWidget> with SingleTickerProviderStateMixin {
  List<FileSystemEntity> audioFiles = [];
  List<PlayerController> playerControllers = [];
  int? _playingIndex;
  bool isPaused = false;
  bool isLoading = true;

  // untuk animasi icon
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _loadAudioFiles();
        // Initialize AnimationController and Animation
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true); // Repeat the animation back and forth

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in playerControllers) {
      controller.dispose();
    }
    _animationController.dispose(); // Dispose AnimationController
    super.dispose();
  }

  Future<void> playAudio(String path, int index) async {
    try {
      print("${index}");
      if(_playingIndex == index && isPaused){
        print('ini if yang pertama: ${_playingIndex == index && isPaused}, ${_playingIndex}, ${isPaused}');
        await playerControllers[index].startPlayer(finishMode: FinishMode.loop);
        setState(() {
          isPaused = false;
        });
      } else if (_playingIndex == index){
        print('ini else if yang pertama: ${_playingIndex}, ${isPaused}');
        await playerControllers[index].pausePlayer();
        setState(() {
          isPaused = true;
        });
      }else{
        print('ini else : ${_playingIndex}, ${isPaused}, ${_playingIndex != index && _playingIndex != null}');
        if(_playingIndex != index && _playingIndex != null){
          await playerControllers[_playingIndex!].pausePlayer();
        }
        setState(() {
          _playingIndex = index;
          isPaused = false;

        });
        await playerControllers[index].startPlayer(finishMode: FinishMode.loop);
      }
    } catch (e) {
      print("Error saat pemutaran suara: $e");
    }
  }

  Future<void> deleteAudio(FileSystemEntity file, int index) async {
    try {
      await file.delete();
      setState(() {
        audioFiles.removeAt(index);
        playerControllers.remove(playerControllers[index]);
        _playingIndex = null;
        isPaused = false;
      });

      Navigator.pushReplacement(
        context,
        FadePageRoute(
          page: BottomNavWidgets(initialIndex: widget.selectedIndex),
        ),
      );

      // Show a Flushbar to notify successful deletion
      Flushbar(
        title: "File Deleted",
        message: "Your recording has been successfully deleted.",
        duration: Duration(seconds: 1), // Increased duration to ensure visibility
        backgroundColor: Colors.green,
        icon: Icon(
          Icons.check_circle,
          color: Colors.white,
        ),
        flushbarPosition: FlushbarPosition.TOP,
        flushbarStyle: FlushbarStyle.FLOATING,
        margin: EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(8),
      )..show(context);

    } catch (e) {
      print("Error saat menghapus file: $e");
    }
  }

  Future<void> _loadAudioFiles() async {
    try {
      final directory = await getExternalStorageDirectory();
      final recordingsDir = Directory('${directory!.path}/MyRecordings');
      if (await recordingsDir.exists()) {
        setState(() {
          audioFiles = recordingsDir.listSync()
          ..sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
          playerControllers = List<PlayerController>.generate(
            audioFiles.length,
            (index) => PlayerController(),
          );
          for (int i = 0; i < audioFiles.length; i++) {
            final file = audioFiles[i];
            final playerController = playerControllers[i];
            playerController.preparePlayer(
              path: file.path,
              shouldExtractWaveform: true,
            );
          }
          isLoading = false; 
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error saat memuat file audio: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showConfirmDelete(BuildContext context, FileSystemEntity file, int index) async {
    if(_playingIndex == index){
      await playerControllers[index].pausePlayer();
      setState(() {
        isPaused = true;
      });
    }else if (_playingIndex !=index && _playingIndex != null){
      await playerControllers[_playingIndex!].pausePlayer();
      setState(() {
        isPaused = true;
      });
    }
    
    AwesomeDialog(
      context: context,
      customHeader: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          // Determine colors based on the animation value
          final isDeleteIcon = _animation.value < 0.5;
          final iconColor = isDeleteIcon ? Colors.red : Colors.deepPurple;
          final borderColor = isDeleteIcon ? Colors.red : Colors.deepPurple;

          return Container(
            decoration: BoxDecoration(
              color: Colors.transparent, // No background color
              borderRadius: BorderRadius.circular(50), // Border radius for rounded corners
              border: Border.all(
                color: borderColor, // Border color based on the icon
                width: 2, // Border width
              ),
            ),
            padding: const EdgeInsets.all(8), // Padding around the icon
            child: Icon(
              isDeleteIcon ? Icons.delete : Icons.question_mark_rounded,
              color: iconColor, // Icon color based on the icon
              size: 50,
            ),
          );
        },
      ),
      animType: AnimType.scale,
      dismissOnTouchOutside: false,
      title: 'Delete Audio',
      desc: "Are you sure you want to delete this audio?",
      btnOkText: "Yes",
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        deleteAudio(file, index);
      },
    ).show();
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
          'Recording Results',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        leading: null,
      ),
      body: SafeArea( 
        child: isLoading
          ? Center(
              child: CircularProgressIndicator(), // Indikator loading
            )
          : audioFiles.isEmpty
          ? Center(
              child: Container(
                width: width*0.5,
                height: isLandscape ? height * 0.25 : height * 0.15,
                child: Opacity(
                  opacity: 0.3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          // Determine colors based on the animation value
                          final isAnimatedIcon = _animation.value < 0.5;
                          final iconColor = isAnimatedIcon ? Colors.blue : Colors.deepPurple;
                          final borderColor = isAnimatedIcon ? Colors.blue : Colors.deepPurple;
                          final textColor = isAnimatedIcon ? Colors.blue : Colors.deepPurple;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.transparent, // No background color
                              borderRadius: BorderRadius.circular(50), // Border radius for rounded corners
                              border: Border.all(
                                color: borderColor, // Border color based on the icon
                                width: 2, // Border width
                              ),
                            ),
                            padding: isLandscape ? const EdgeInsets.all(10) : const EdgeInsets.all(20), // Padding around the icon
                            child: Icon(
                              isAnimatedIcon ? Icons.search_off_rounded : Icons.search,
                              color: iconColor, // Icon color based on the icon
                              size: isLandscape ? 40 : 50,
                            ),
                          );
                        },
                      ),
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          // Determine colors based on the animation value
                          final isAnimatedIcon = _animation.value < 0.5;
                          final textColor = isAnimatedIcon ? Colors.blue : Colors.deepPurple;

                          return Container(
                            child: Text(
                              "Blank Audio Data",
                              style: TextStyle(
                                color: textColor,
                                fontSize: isLandscape ? 15 : 20
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
            )
          : ListView.builder(
          scrollDirection: Axis.vertical,
          itemCount: audioFiles.length,
          itemBuilder: (context, index) {
            final file = audioFiles[index];
            final fileName = file.path.split('/').last;
            final playerController = playerControllers[index];
            return Column(
              children: [
                Card(
                  color: Colors.grey[700],
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            fileName, 
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            // Icon play/pause
                            IconButton(
                              icon: Icon(
                                _playingIndex == index && !isPaused
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.blue,
                              ),
                              onPressed: () {
                                playAudio(file.path, index);
                              }
                            ),
                            // Audio Waveforms
                            Expanded(
                              child: AudioFileWaveforms(
                                playerController: playerController,
                                size: Size(width, 30),
                                enableSeekGesture: true,
                                // waveformData: [],
                                waveformType: WaveformType.long,
                                playerWaveStyle: const PlayerWaveStyle(
                                  fixedWaveColor: Colors.white,
                                  liveWaveColor: Colors.blueAccent,
                                  waveThickness: 2.0, // Ketebalan wave
                                  seekLineThickness: 2.0,
                                  showSeekLine: false,
                                ),
                              ),
                            ),
                            // Icon share
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.blue),
                              onPressed: () {
                                // shareAudio(File(file.path)); // Share audio file
                              },
                            ),
                            // Icon delete
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _showConfirmDelete(context, file, index);
                                // deleteAudio(file, index);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
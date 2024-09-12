import 'dart:io';

import 'package:agc_record/pages/fadepageroute.dart';
import 'package:agc_record/widgets/bottomnav.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class shareWidget extends StatefulWidget {
  final int selectedIndex;
  const shareWidget({super.key, required this.selectedIndex});

  @override
  State<shareWidget> createState() => _shareWidgetState();
}

class _shareWidgetState extends State<shareWidget> {
  List<FileSystemEntity> audioFiles = [];
  List<PlayerController> playerControllers = [];
  int? _playingIndex;
  bool isPaused = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAudioFiles();
  }

  @override
  void dispose() {
    for (var controller in playerControllers) {
      controller.dispose();
    }
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
      print("${file},${playerControllers}, ${index}");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: const Text(
          'Share',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea( 
        child: isLoading
          ? Center(
              child: CircularProgressIndicator(), // Indikator loading
            )
          : audioFiles.isEmpty
          ? Center(
              child: Container(
                width: MediaQuery.of(context).size.width*0.5,
                height: MediaQuery.of(context).size.height*0.15,
                child: Opacity(
                  opacity: 0.5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 100,
                      ),
                      Text(
                        "Data Audio Kosong",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 20
                        ),
                      )
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
                                size: Size(MediaQuery.of(context).size.width, 30),
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
                                deleteAudio(file, index);
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
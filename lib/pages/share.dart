import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class shareWidget extends StatefulWidget {
  const shareWidget({super.key});
  
  @override
  State<shareWidget> createState() => _shareWidgetState();
}

class _shareWidgetState extends State<shareWidget> {
  late final PlayerController playerController;
  List<FileSystemEntity> audioFiles = [];
  int? _playingIndex; // Menyimpan index file yang sedang diputar
  bool isPaused = false; // Menyimpan status audio apakah sedang di-pause atau tidak
  Map<int, List<double>> waveforms = {};

  @override
  void initState() {
    super.initState();
    playerController = PlayerController();
    _loadAudioFiles(); 
  }

  @override
  void dispose() {
    playerController.dispose();
    super.dispose();
  }

  // Fungsi untuk mengambil semua file rekaman di folder MyRecordings
  Future<void> _loadAudioFiles() async {
    final directory = await getExternalStorageDirectory();
    final recordingsDir = Directory('${directory!.path}/MyRecordings');
    if (await recordingsDir.exists()) {
      setState(() {
        audioFiles = recordingsDir.listSync(); // Ambil semua file dalam folder
      });
      for (int i = 0; i < audioFiles.length; i++) {
        final file = audioFiles[i];
        await ekstrakAudio(file.path, i);  // Ekstrak waveform saat memuat file
      }
    }
  }

  Future<void> ekstrakAudio(String path, int index) async {
    try {
      // Mengambil data waveform dalam bentuk List<double>
      final List<double> waveform = await playerController.extractWaveformData(path: path);

      setState(() {
        // Simpan data waveform berdasarkan index file audio
        waveforms[index] = waveform;
      });
    } catch (e) {
      print('Error extracting waveform: $e');
    }
  }


  Future<void> playAudio(String path, int index) async {
    try {
      if (_playingIndex == index && isPaused) {
        // Jika audio di-pause, lanjutkan dari posisi terakhir
        await playerController.startPlayer(finishMode: FinishMode.loop);
        setState(() {
          isPaused = false;
        });
      } else if (_playingIndex == index) {
        // Jika audio sedang diputar, hentikan pemutaran (pause)
        await playerController.pausePlayer();
        setState(() {
          isPaused = true;
        });
      } else {
        // Jika ada audio lain yang sedang diputar, hentikan terlebih dahulu
        if (_playingIndex != null) {
          await playerController.stopPlayer();
        }

        // Siapkan pemutar audio untuk audio baru
        setState(() {
          _playingIndex = index;
          isPaused = false;
        });
        
        // Menyiapkan player untuk file audio baru
        await playerController.preparePlayer(path: path);

        // Mulai pemutaran dari awal
        await playerController.startPlayer(finishMode: FinishMode.loop);
      }
    } catch (e) {
      print("Ini error saat pemutaran suara: $e");
    }
  }

  // Fungsi untuk menghapus rekaman
  Future<void> deleteAudio(FileSystemEntity file, int index) async {
    try {
      await file.delete();
      setState(() {
        audioFiles.removeAt(index);
      });
    } catch (e) {
      print("ini error saat penghapusan: $e");
    }
  }

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
      body: ListView.builder(
              scrollDirection: Axis.vertical,
              itemCount: audioFiles.length,
              itemBuilder: (context, index) {
                final file = audioFiles[index];
                final fileName = file.path.split('/').last; // Mengambil nama file
                return Column(
                  children: [
                    Card(
                      color: Colors.grey[700], // Warna latar belakang gelap
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                fileName, // Menampilkan nama file di atas waveform
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
                                    _playingIndex == index && !isPaused ? Icons.pause : Icons.play_arrow,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    playAudio(file.path, index); // Memutar audio sesuai index
                                  },
                                ),
                                // Audio waveform dimulai dari samping icon play
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8.0), // Tambah padding agar dimulai dari samping icon
                                    child: 
                                    AudioFileWaveforms(
                                      playerController: playerController,
                                      size: Size(MediaQuery.of(context).size.width, 30),
                                      enableSeekGesture: true, // Aktifkan gesture seek
                                      waveformData: [], // Gunakan data dari state
                                      playerWaveStyle: PlayerWaveStyle(
                                        fixedWaveColor: Colors.blueGrey, // Warna abu-abu biru sebelum diputar
                                        liveWaveColor: Colors.blueAccent, // Warna biru saat audio diputar
                                        waveThickness: 2.0, // Ketebalan wave
                                      ),
                                    ),
                                  ),
                                ),
                                // Icon share
                                IconButton(
                                  icon: const Icon(Icons.share, color: Colors.blue),
                                  onPressed: () {
                                    // shareAudio(file); // Share audio file
                                  },
                                ),
                                // Icon delete
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    deleteAudio(file, index); // Hapus file audio
                                  },
                                ),
                              ],
                            ),
                          ],
                        )
                      ),
                    ),
                  ],
                );
              },
            )
    );
  }
}
import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:agc_record/pages/fade_page_route.dart';
import 'package:agc_record/widgets/bottom_nav.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:agc_record/utils/helper.dart';
import 'package:logger/logger.dart';
import 'package:ntp/ntp.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class RecordingResultsWidget extends StatefulWidget {
  final int selectedIndex;
  const RecordingResultsWidget({super.key, required this.selectedIndex});

  @override
  State<RecordingResultsWidget> createState() => _RecordingResultsWidgetState();
}

class _RecordingResultsWidgetState extends State<RecordingResultsWidget> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final FlutterFFmpeg _ffmpeg = FlutterFFmpeg();
  List<FileSystemEntity> audioFiles = [];
  List<PlayerController> playerControllers = [];
  Map<String, int> fileToIndexMap = {};
  String? _playingFilePath;
  bool isPaused = false;
  bool isLoading = true;
  bool isSharing = false;
  String? sharingFilePath;
  String searchQuery = '';
  String sortOrder = 'terbaru';
  double delayFromServerSeconds = 0.0;

  // untuk animasi icon
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Tambahkan variabel untuk menyimpan hasil filter dan sort
  List<FileSystemEntity> _filteredFiles = [];

  Timer? _debounce;

  var logger = Logger();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAudioFiles();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )
      ..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    for (var controller in playerControllers) {
      controller.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _reinitializeState();
  }

  Future<void> playAudio(String path, int index) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        logger.e('File tidak ditemukan: $path');
        return;
      }

      final fileSize = await file.length();
      logger.i('Ukuran file: $fileSize bytes');
      if (fileSize == 0) {
        logger.e('File kosong: $path');
        return;
      }

      await playerControllers[index].setVolume(1.0);

      logger.i('Memulai pemutaran audio');
      logger.i('Path: $path');
      logger.i('Index: $index');
      logger.i(
          'Player controller state: ${playerControllers[index].playerState}');

      if (_playingFilePath == path && isPaused) {
        logger.i('Melanjutkan pemutaran yang di-pause');
        await playerControllers[index].startPlayer(
            finishMode: FinishMode.loop
        );
        setState(() {
          isPaused = false;
        });
      } else if (_playingFilePath == path) {
        logger.i('Menghentikan pemutaran');
        await playerControllers[index].pausePlayer();
        setState(() {
          isPaused = true;
        });
      } else {
        logger.i('Memulai pemutaran baru');
        if (_playingFilePath != null) {
          final oldIndex = fileToIndexMap[_playingFilePath!];
          if (oldIndex != null) {
            await playerControllers[oldIndex].pausePlayer();
          }
        }
        setState(() {
          _playingFilePath = path;
          isPaused = false;
        });

        await playerControllers[index].startPlayer(
            finishMode: FinishMode.loop
        );
      }
    } catch (e) {
      logger.e("Error saat memutar audio", error: e);
    }
  }

  Future<void> deleteAudio(FileSystemEntity file, int index) async {
    try {
      await file.delete();
      if (mounted) {
        setState(() {
          audioFiles.removeAt(index);
          playerControllers.removeAt(index);
          if (_playingFilePath == file.path) {
            _playingFilePath = null;
            isPaused = false;
          }
          // Update fileToIndexMap
          fileToIndexMap = Map.fromEntries(
              audioFiles
                  .asMap()
                  .entries
                  .map((entry) => MapEntry(entry.value.path, entry.key))
          );
        });
        Navigator.pushReplacement(
          context,
          FadePageRoute(
            page: BottomNavWidgets(initialIndex: widget.selectedIndex),
          ),
        );
        Flushbar(
          title: "File Deleted",
          message: "Your recording has been successfully deleted.",
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
    } catch (e) {
      var logger = Logger();
      logger.e("Error log", error: e);
    }
  }

  Future<void> _loadAudioFiles() async {
    try {
      final directory = await getExternalStorageDirectory();
      final recordingsDir = Directory('${directory!.path}/MyRecordings');
      if (await recordingsDir.exists()) {
        final files = recordingsDir.listSync();
        files.sort((a, b) {
          final aName = a.uri.pathSegments.last;
          final bName = b.uri.pathSegments.last;

          final aRaw = FileHelper.extractTanggalDanWaktu(aName);
          final bRaw = FileHelper.extractTanggalDanWaktu(bName);

          if (aRaw == null || bRaw == null) return 0;

          // Urut dari terbaru ke terlama
          return bRaw.compareTo(aRaw);
        });

        // Filter hanya file audio yang valid
        final validFiles = files.where((file) => _isValidAudioFile(file.path))
            .toList();

        setState(() {
          audioFiles = validFiles;
          // Buat map untuk menyimpan index asli
          fileToIndexMap = Map.fromEntries(
              audioFiles
                  .asMap()
                  .entries
                  .map((entry) => MapEntry(entry.value.path, entry.key))
          );
          playerControllers = List<PlayerController>.generate(
            audioFiles.length,
                (index) => PlayerController(),
          );
        });

        await _initializePlayers();

        setState(() {
          isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      logger.e("Error saat memuat file audio", error: e);
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Fungsi baru untuk inisialisasi player
  Future<void> _initializePlayers() async {
    for (int i = 0; i < audioFiles.length; i++) {
      final file = audioFiles[i];
      final playerController = playerControllers[i];

      // Cek file exists
      if (await File(file.path).exists()) {
        logger.i('File audio ditemukan: ${file.path}');
        logger.i('Ukuran file: ${await File(file.path).length()} bytes');

        try {
          // Reset player controller jika sudah ada
          playerController.dispose();
          playerControllers[i] = PlayerController();

          // Inisialisasi ulang dengan parameter tambahan
          await playerControllers[i].preparePlayer(
            path: file.path,
            shouldExtractWaveform: true,
            noOfSamples: 100,
            volume: 1.0,
          );

          // Hanya tambahkan satu listener untuk state changes
          playerControllers[i].onPlayerStateChanged.listen((state) {
            logger.i('Player $i state changed to: $state');
          });

          logger.i('Player berhasil diinisialisasi untuk file: ${file.path}');
        } catch (e) {
          logger.e('Error saat inisialisasi player: $e');
        }
      } else {
        logger.e('File audio tidak ditemukan: ${file.path}');
      }
    }
  }

  void _showConfirmDelete(context, FileSystemEntity file, int index,
      String name) async {
    if (_playingFilePath == file.path) {
      await playerControllers[index].pausePlayer();
      setState(() {
        isPaused = true;
      });
    } else if (_playingFilePath != null) {
      final oldIndex = fileToIndexMap[_playingFilePath!];
      if (oldIndex != null) {
        await playerControllers[oldIndex].pausePlayer();
      }
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
              color: Colors.transparent,
              // No background color
              borderRadius: BorderRadius.circular(50),
              // Border radius for rounded corners
              border: Border.all(
                color: borderColor, // Border color based on the icon
                width: 2, // Border width
              ),
            ),
            padding: const EdgeInsets.all(8), // Padding around the icon
            child: Icon(
              isDeleteIcon ? Icons.delete_outline : Icons.question_mark_rounded,
              color: iconColor, // Icon color based on the icon
              size: 50,
            ),
          );
        },
      ),
      animType: AnimType.scale,
      dismissOnTouchOutside: false,
      title: '${name}',
      desc: "Apakah Anda yakin ingin menghapus audio ini?",
      btnOkText: "Ya",
      btnCancelText: "Batal",
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        deleteAudio(file, index);
      },
    ).show();
  }

  Future<void> _showConfirmShare(context, FileSystemEntity file, int index,
      String name) async {
    if (_playingFilePath == file.path) {
      await playerControllers[index].pausePlayer();

      setState(() {
        isPaused = true;
      });
    } else if (_playingFilePath != null) {
      final oldIndex = fileToIndexMap[_playingFilePath!];
      if (oldIndex != null) {
        await playerControllers[oldIndex].pausePlayer();
      }
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
          final iconColor = isDeleteIcon ? Colors.green : Colors.deepPurple;
          final borderColor = isDeleteIcon ? Colors.green : Colors.deepPurple;

          return Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              // No background color
              borderRadius: BorderRadius.circular(50),
              // Border radius for rounded corners
              border: Border.all(
                color: borderColor, // Border color based on the icon
                width: 2, // Border width
              ),
            ),
            padding: const EdgeInsets.all(8), // Padding around the icon
            child: Icon(
              isDeleteIcon ? Icons.share_outlined : Icons.question_mark_rounded,
              color: iconColor, // Icon color based on the icon
              size: 50,
            ),
          );
        },
      ),
      animType: AnimType.scale,
      dismissOnTouchOutside: false,
      title: '${name}',
      desc: "Apakah Anda yakin ingin membagikan audio ini?",
      btnOkText: "Ya",
      btnCancelText: "Batal",
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        setState(() {
          isSharing = true;
          sharingFilePath = file.path;
        });

        try {
          String wavFilePath = await convertToWav(file.path);
          File wavFile = File(wavFilePath);

          if (await wavFile.exists()) {
            await uploadAudioFile(wavFile);
          } else {
            var logger = Logger();
            logger.e('File not found');
          }
        } catch (e) {
          var logger = Logger();
          logger.e('Error during upload: $e');
        } finally {
          if (mounted) {
            setState(() {
              isSharing = false;
              sharingFilePath = null;
            });
          }
        }
      },
    ).show();
  }


  Future<String> convertToWav(String inputPath) async {
    final outputPath = inputPath.replaceAll(
        ".mp3", ".wav"); // atau sesuaikan format input
    await _ffmpeg.execute("-i $inputPath $outputPath");
    return outputPath;
  }

  Future<void> uploadAudioFile(File file) async {
    String currentTime = DateTime.now().toIso8601String(); // Format: YYYY-MM-DDTHH:mm:ss.sssZ
    String sumber = "Mobile";

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://agcrecord.batutech.cloud/upload-audio'),
    );

    request.fields['process_time'] = currentTime;
    request.fields['sumber_pengirim'] = sumber;

    request.files.add(
      await http.MultipartFile.fromPath(
        'audio',
        file.path,
      ),
    );

    // Menambahkan waktu proses ke request
    var response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final Map<String, dynamic> responseJson = json.decode(responseBody);

    if (response.statusCode == 200) {
      var log = Logger();
      log.i('plot: ${responseJson['plot']}');
      log.i('audio: ${responseJson['audio']}');
      var delayFromServer = responseJson['delay'];
      delayFromServerSeconds = delayFromServer;
      int delayFromServerMilliseconds = (delayFromServer * 1000).toInt();
      var delayPushFromServer = responseJson['delay_push'];
      int idFromServer = responseJson['id'];
      String outputFileFromServer = responseJson['output_files'];
      String startPullServerString = responseJson['start_pull_server'];
      var startPushServer = responseJson['start_time_pengiriman'];
      var startPushServerMiliseconds = responseJson['start_time_pengiriman_miliseconds'];
      int startPullServerMillisecondsFromServer = responseJson['start_pull_server_miliseconds'];

      String plotFilename = responseJson['plot'];
      String audioFilename = responseJson['audio']; // Get the audio filename from response

      if (plotFilename.isNotEmpty) {
        if (await Permission.storage.request().isGranted) {
          if (mounted) {
            // Create a new instance of MediaDownloader
            final downloader = MediaDownloader(context: context);

            // Download both plot and audio
            final result = await downloader.downloadMedia(plotFilename, audioFilename);

            if (result != null && result['status'] == 'success') {
              var endTimeClientPull = await NTP.now();
              DateTime startPullServerDateTime = DateTime.parse(startPullServerString);
              Duration clientToServerDelay = (endTimeClientPull.difference(startPullServerDateTime));
              int clientToServerDelayMilliseconds = clientToServerDelay.inMilliseconds;
              var clientToServerDelaySeconds = clientToServerDelayMilliseconds / 1000;
              int delayTotalMilliseconds = clientToServerDelayMilliseconds + delayFromServerMilliseconds;
              var delayTotalSeconds = delayTotalMilliseconds / 1000;

              // Update delay information in the downloader
              downloader.updateDelayInfo(
                  delayPushFromServer.toStringAsFixed(2),
                  delayFromServerSeconds.toStringAsFixed(2),
                  clientToServerDelaySeconds.toStringAsFixed(2),
                  delayTotalSeconds.toStringAsFixed(2)
              );

              // Kirim data delay ke Flask
              await updateDelayToServer(
                id: idFromServer.toString(),
                delayPullServerSeconds: clientToServerDelaySeconds.toString(),
                delayPullServerMiliseconds: clientToServerDelayMilliseconds.toString(),
                delayTotal: delayTotalSeconds.toString(),
                endPullServer: endTimeClientPull.toString(),
                namaFile: outputFileFromServer.toString(),
                startPullServer: startPullServerString.toString(),
                startPullServerMiliseconds: startPullServerMillisecondsFromServer.toString(),
                startPushServer: startPushServer.toString(),
                startPushServerMiliseconds: startPushServerMiliseconds.toString(),
                delayTotalMiliseconds: delayTotalMilliseconds.toString(),
              );
            }
          }
        }
      }
    } else {
      // Membuat JSON untuk status gagal
      Map<String, dynamic> jsonResponse = {
        'status': 'gagal mengungah',
        'delay_send': '-',
        'delay_server': '-',
        'delay_memuat': '-',
        'delay_total': '-',
      };

      if (mounted) {
        showUploadResult(jsonResponse);
      }
    }
  }

  Future<void> updateDelayToServer({
    required String id,
    required String delayPullServerSeconds,
    required String delayPullServerMiliseconds,
    required String delayTotal,
    required String endPullServer,
    required String namaFile,
    required String startPullServer,
    required String startPullServerMiliseconds,
    required String startPushServer,
    required String startPushServerMiliseconds,
    required String delayTotalMiliseconds,
  }) async {
    var logger = Logger();

    try {
      final response = await http.post(
        Uri.parse('https://agcrecord.batutech.cloud/update-delay'),
        body: {
          'id': id,
          'namaFile': namaFile,
          'startPushServer': startPushServer,
          'startPushServerMiliseconds': startPushServerMiliseconds,
          'startPullServer': startPullServer,
          'startPullServerMiliseconds': startPullServerMiliseconds,
          'endPullServer': endPullServer,
          'delayPullServerMiliseconds': delayPullServerMiliseconds,
          'delayPullServerSeconds': delayPullServerSeconds,
          'delayTotal': delayTotal,
          'delayTotalMiliseconds': delayTotalMiliseconds,
        },
      );

      if (response.statusCode == 200) {
        logger.i('Berhasil mengirim data delay ke server: ${response.body}');
      } else {
        logger.e('Gagal mengirim data delay ke server: ${response
            .statusCode}, ${response.body}');
      }
    } catch (e) {
      logger.e('Error saat mengirim data delay: $e');
    }
  }

  void showUploadResult(Map<String, dynamic> response) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Unggah Ke Cloud"),
          content: Text(
            'status: ${response['status']}\n'
                'delay_send: ${response['delay_send']} detik\n'
                'delay_server: ${response['delay_server']} detik\n'
                'delay_memuat: ${response['delay_memuat']} detik\n'
                'Total Delay: ${response['delay_total']} detik',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  bool _isValidAudioFile(String path) {
    final file = File(path);
    final extension = path
        .split('.')
        .last
        .toLowerCase();
    return file.existsSync() && (extension == 'wav' || extension == 'mp3');
  }

  // Fungsi untuk menginisialisasi ulang state
  Future<void> _reinitializeState() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Hentikan semua pemutaran yang sedang berlangsung
      if (_playingFilePath != null) {
        final currentIndex = fileToIndexMap[_playingFilePath];
        if (currentIndex != null) {
          await playerControllers[currentIndex].pausePlayer();
        }
      }

      // Dispose semua player controller
      for (var controller in playerControllers) {
        controller.dispose();
      }

      // Reset state
      playerControllers = [];
      _playingFilePath = null;
      isPaused = false;
      _filteredFiles = [];

      // Load ulang file audio
      final directory = await getExternalStorageDirectory();
      final recordingsDir = Directory('${directory!.path}/MyRecordings');
      if (await recordingsDir.exists()) {
        final files = recordingsDir.listSync();
        files.sort((a, b) {
          final aName = a.uri.pathSegments.last;
          final bName = b.uri.pathSegments.last;

          final aRaw = FileHelper.extractTanggalDanWaktu(aName);
          final bRaw = FileHelper.extractTanggalDanWaktu(bName);

          if (aRaw == null || bRaw == null) return 0;

          // Urut dari terbaru ke terlama
          return bRaw.compareTo(aRaw);
        });


        final validFiles = files.where((file) => _isValidAudioFile(file.path))
            .toList();

        setState(() {
          audioFiles = validFiles;
          fileToIndexMap = Map.fromEntries(
              audioFiles
                  .asMap()
                  .entries
                  .map((entry) => MapEntry(entry.value.path, entry.key))
          );
          playerControllers = List<PlayerController>.generate(
            audioFiles.length,
                (index) => PlayerController(),
          );
        });

        // Inisialisasi player controllers
        for (int i = 0; i < audioFiles.length; i++) {
          final file = audioFiles[i];
          final playerController = playerControllers[i];

          if (await File(file.path).exists()) {
            logger.i('File audio ditemukan: ${file.path}');
            logger.i('Ukuran file: ${await File(file.path).length()} bytes');

            try {
              await playerController.preparePlayer(
                path: file.path,
                shouldExtractWaveform: true,
                noOfSamples: 100,
                volume: 1.0,
              );

              playerController.onPlayerStateChanged.listen((state) {
                logger.i('Player $i state changed to: $state');
              });

              logger.i(
                  'Player berhasil diinisialisasi untuk file: ${file.path}');
            } catch (e) {
              logger.e('Error saat inisialisasi player: $e');
            }
          } else {
            logger.e('File audio tidak ditemukan: ${file.path}');
          }
        }
      }
    } catch (e) {
      logger.e("Error saat menginisialisasi ulang state", error: e);
    } finally {
      setState(() {
        isLoading = false;
      });
      _updateFilteredFiles();
    }
  }

  // Fungsi untuk memperbarui filtered files
  void _updateFilteredFiles() {
    var filtered = audioFiles.where((file) {
      final fileName = file.path
          .split('/')
          .last
          .toLowerCase();
      final searchTerms = searchQuery.toLowerCase().split(' ');

      // Cek apakah semua kata kunci ada di nama file
      return searchTerms.every((term) => fileName.contains(term));
    }).toList();

    if (sortOrder == 'terbaru') {
      filtered.sort((a, b) {
        final aName = a.uri.pathSegments.last;
        final bName = b.uri.pathSegments.last;

        final aRaw = FileHelper.extractTanggalDanWaktu(aName);
        final bRaw = FileHelper.extractTanggalDanWaktu(bName);

        if (aRaw == null || bRaw == null) return 0;

        // Terbaru ke terlama
        return bRaw.compareTo(aRaw);
      });
    } else {
      filtered.sort((a, b) {
        final aName = a.uri.pathSegments.last;
        final bName = b.uri.pathSegments.last;

        final aRaw = FileHelper.extractTanggalDanWaktu(aName);
        final bRaw = FileHelper.extractTanggalDanWaktu(bName);

        if (aRaw == null || bRaw == null) return 0;

        // Terbaru ke terlama
        return aRaw.compareTo(bRaw);
      });
    }

    setState(() {
      _filteredFiles = filtered;
    });
  }

  // Fungsi untuk menangani perubahan search dengan debounce
  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _reinitializeState();
      setState(() {
        searchQuery = value;
      });
      _updateFilteredFiles();
    });
  }

  // Ganti getter dengan fungsi yang memanggil _updateFilteredFiles
  List<FileSystemEntity> get filteredAndSortedFiles {
    if (_filteredFiles.isEmpty) {
      _updateFilteredFiles();
    }
    return _filteredFiles;
  }



  @override
  Widget build(BuildContext context) {
    var width = MediaQuery
        .of(context)
        .size
        .width;

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
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 12.0),
              color: Colors.white,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari Berdasarkan Nama...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 16),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.filter_list,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          sortOrder = 'terbaru';
                          _reinitializeState();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sortOrder == 'terbaru'
                                ? Colors.blueAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Terbaru',
                            style: TextStyle(
                              color: sortOrder == 'terbaru'
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: sortOrder == 'terbaru' ? FontWeight
                                  .bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          sortOrder = 'terlama';
                          _reinitializeState();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sortOrder == 'terlama'
                                ? Colors.blueAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Terlama',
                            style: TextStyle(
                              color: sortOrder == 'terlama'
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: sortOrder == 'terlama' ? FontWeight
                                  .bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Divider between search and content
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            // Content Area
            isLoading
                ? const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: CircularProgressIndicator(
                        color: Colors.blueAccent,
                      ),
                    )
                  ],
                ),
              ),
            )
                : Expanded(
              child: filteredAndSortedFiles.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Empty state animation
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final isAnimatedIcon = _animation.value < 0.8;
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(60),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Icon(
                            isAnimatedIcon ? Icons.search_off_rounded : Icons
                                .headphones,
                            color: isAnimatedIcon ? Colors.blueAccent : Colors
                                .deepPurple,
                            size: 72,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    Text(
                      searchQuery.isEmpty
                          ? "Belum ada file audio"
                          : "Tidak ada hasil untuk",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        searchQuery.isEmpty
                            ? "Rekam audio baru untuk melihat hasil Anda di sini"
                            : "Coba kata kunci pencarian yang berbeda",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                scrollDirection: Axis.vertical,
                itemCount: filteredAndSortedFiles.length,
                itemBuilder: (context, index) {
                  final file = filteredAndSortedFiles[index];
                  final fileName = file.path
                      .split('/')
                      .last;
                  final originalIndex = fileToIndexMap[file.path] ?? 0;
                  final playerController = playerControllers[originalIndex];
                  String? rawTanggalWaktu = FileHelper.extractTanggalDanWaktu(
                      fileName);
                  String? tampilTanggal = FileHelper.formatTanggalDenganWaktu(
                      rawTanggalWaktu);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with filename and date
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fileName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Row(
                              children: [
                                Text(
                                  tampilTanggal!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Audio player dan action buttons
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Row(
                              children: [
                                // Play/pause button
                                Container(
                                  height: 44,
                                  width: 44,
                                  decoration: BoxDecoration(
                                    color: _playingFilePath == file.path &&
                                        !isPaused
                                        ? Colors.blueAccent
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      _playingFilePath == file.path && !isPaused
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: _playingFilePath == file.path &&
                                          !isPaused
                                          ? Colors.white
                                          : Colors.blueAccent,
                                    ),
                                    onPressed: () {
                                      playAudio(file.path, originalIndex);
                                    },
                                    iconSize: 24,
                                    padding: EdgeInsets.zero,
                                  ),
                                ),

                                // Audio waveforms
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: AudioFileWaveforms(
                                      playerController: playerController,
                                      size: Size(width - 140, 40),
                                      enableSeekGesture: true,
                                      waveformType: WaveformType.long,
                                      playerWaveStyle: const PlayerWaveStyle(
                                        fixedWaveColor: Color(0xFFE0E0E0),
                                        liveWaveColor: Colors.blueAccent,
                                        waveThickness: 2.5,
                                        seekLineThickness: 2.0,
                                        showSeekLine: true,
                                        seekLineColor: Colors.blueAccent,
                                      ),
                                    ),
                                  ),
                                ),

                                // Share button
                                isSharing && sharingFilePath == file.path
                                    ? Container(
                                  width: 36,
                                  height: 36,
                                  padding: const EdgeInsets.all(8),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.blueAccent),
                                  ),
                                )
                                    : IconButton(
                                  onPressed: isSharing ? null : () async {
                                    await _showConfirmShare(context, file, originalIndex, fileName);
                                  },
                                  icon: const Icon(
                                      Icons.share_outlined, size: 20),
                                  color: Colors.blueAccent,
                                ),

                                // Delete button
                                IconButton(
                                  onPressed: () {
                                    _showConfirmDelete(
                                        context, file, originalIndex, fileName);
                                  },
                                  icon: const Icon(
                                      Icons.delete_outline, size: 20),
                                  color: Colors.redAccent,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MediaDownloader {
  final BuildContext context;
  AwesomeDialog? _dialog;
  double _progressValue = 0.0;
  int _progressPercentage = 0;
  String _progressText = '0%';
  var log = Logger();
  late void Function(int received, int total) _updateProgress;
  bool _isDownloadComplete = false;
  String _plotPathDownloaded = '';
  String _audioPathDownloaded = '';
  String _delaySend = '';
  String _delayServer = '';
  String _delayClient = '';
  String _delayTotal = '';
  bool _showingDelayInfo = false;
  String _currentDownloadType = 'plot';
  StateSetter? _dialogSetState;

  // Constructor
  MediaDownloader({required this.context});

  Future<Map<String, dynamic>?> downloadMedia(String plotFilename, String audioFilename) async {
    if (plotFilename.isEmpty) {
      _showErrorDialog('Nama file plot tidak valid');
      return null;
    }

    if (audioFilename.isEmpty) {
      _showErrorDialog('Nama file audio tidak valid');
      return null;
    }

    if (await Permission.storage.request().isGranted) {
      try {
        // First download the plot
        _currentDownloadType = 'plot';
        _showProgressDialog(); // Show initial dialog for plot download

        final plotResult = await _downloadPlot(plotFilename);
        if (plotResult == null || plotResult['status'] != 'success') {
          return null;
        }

        // Then download the audio
        _currentDownloadType = 'audio';
        _resetProgress(); // Update dialog to show audio download progress

        final audioResult = await _downloadAudio(audioFilename);
        if (audioResult == null || audioResult['status'] != 'success') {
          return null;
        }

        // Both downloads successful
        return {
          'status': 'success',
          'plotFilePath': _plotPathDownloaded,
          'audioFilePath': _audioPathDownloaded
        };
      } catch (e) {
        _dismissDialog();
        _showErrorDialog('Kesalahan saat mengunduh media: $e');
        return null;
      }
    } else {
      _showErrorDialog('Izin penyimpanan tidak diberikan');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _downloadPlot(String plotFilename) async {
    try {
      final dio = Dio();
      final plotUrl = 'https://agcrecord.batutech.cloud/api/download-plot/$plotFilename';

      final dir = await getExternalStorageDirectory();
      final path = Directory('${dir!.path}/download/plot');

      if (!await path.exists()) {
        await path.create(recursive: true);
        log.i("📁 Folder plot dibuat: ${path.path}");
      }

      final filePath = '${path.path}/$plotFilename';

      final responseDownload = await dio.download(
        plotUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _updateProgress(received, total);
            print("📥 Progres unduh plot: ${(received / total * 100).toStringAsFixed(0)}%");
          }
        },
      );

      if (responseDownload.statusCode == 200) {
        log.i('✅ Gambar plot berhasil diunduh dan disimpan di: $filePath');

        _updateProgress(1, 1); // Update to 100%

        // Store the file path for the success dialog
        _plotPathDownloaded = filePath;

        // Small delay to show 100% complete before proceeding
        await Future.delayed(const Duration(milliseconds: 500));

        return {
          'status': 'success',
          'filePath': filePath
        };
      } else {
        _dismissDialog();
        _showErrorDialog('Gagal mengunduh gambar plot. Status: ${responseDownload.statusCode}');
        return null;
      }
    } catch (e) {
      _dismissDialog();
      _showErrorDialog('Kesalahan saat mengunduh gambar plot: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _downloadAudio(String audioFilename) async {
    try {
      final dio = Dio();
      final audioUrl = 'https://agcrecord.batutech.cloud/api/audio/hasil_agc/$audioFilename';

      final dir = await getExternalStorageDirectory();
      final path = Directory('${dir!.path}/download/audioagc');

      if (!await path.exists()) {
        await path.create(recursive: true);
        log.i("📁 Folder audio dibuat: ${path.path}");
      }

      final filePath = '${path.path}/$audioFilename';

      final responseDownload = await dio.download(
        audioUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _updateProgress(received, total);
            print("📥 Progres unduh audio: ${(received / total * 100).toStringAsFixed(0)}%");
          }
        },
      );

      if (responseDownload.statusCode == 200) {
        log.i('✅ File audio berhasil diunduh dan disimpan di: $filePath');

        _updateProgress(1, 1); // Update to 100%

        // Store the file path for the success dialog
        _audioPathDownloaded = filePath;
        _isDownloadComplete = true;

        // Small delay to show 100% complete
        await Future.delayed(const Duration(milliseconds: 500));

        return {
          'status': 'success',
          'filePath': filePath
        };
      } else {
        _dismissDialog();
        _showErrorDialog('Gagal mengunduh file audio. Status: ${responseDownload.statusCode}');
        return null;
      }
    } catch (e) {
      _dismissDialog();
      _showErrorDialog('Kesalahan saat mengunduh file audio: $e');
      return null;
    }
  }

  void _resetProgress() {
    _progressValue = 0.0;
    _progressPercentage = 0;
    _progressText = '0%';
  }

  void _showProgressDialog() {
    _dialog = AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.scale,
      dismissOnBackKeyPress: false,
      dismissOnTouchOutside: false,
      body: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          _dialogSetState = setState;
          _updateProgress = (received, total) {
            setState(() {
              _progressValue = received / total;
              _progressPercentage = (_progressValue * 100).toInt();
              _progressText = '$_progressPercentage%';

              // Update status jika download selesai
              if (received == total && total > 0) {
                if (_currentDownloadType == 'audio') {
                  _isDownloadComplete = true;
                }
              }
            });
          };

          Widget buildSuccessContent() {
            String downloadTitle = _currentDownloadType == 'plot'
                ? 'Mengunduh Gambar Plot'
                : 'Mengunduh File Audio';

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isDownloadComplete ? 'Unduhan Berhasil' : (_currentDownloadType == 'plot' ? 'Mengunduh Gambar Plot' : 'Mengunduh File Audio'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Kontainer lokasi file
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Lokasi plot:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        (_plotPathDownloaded.isEmpty && !_isDownloadComplete)
                            ? const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Mengunduh plot...'),
                          ],
                        ): Text(_plotPathDownloaded.isNotEmpty ? _plotPathDownloaded : '-', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 12),
                        // Bagian informasi path lokasi audio
                        const Text('Lokasi audio:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        (_audioPathDownloaded.isEmpty && !_isDownloadComplete)
                            ? const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Mengunduh audio...'),
                          ],
                        ): Text(_audioPathDownloaded.isNotEmpty ? _audioPathDownloaded : '-', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),

                  // Delay info
                  if (_showingDelayInfo && _delaySend.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Informasi Delay:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Delay Kirim (Push): $_delaySend detik'),
                    Text('Delay Server: $_delayServer detik'),
                    Text('Delay Tarik (Pull): $_delayClient detik'),
                    Text('Total Delay: $_delayTotal detik'),
                  ],

                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        _dismissDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      child: Text(_isDownloadComplete ? 'OK' : 'Batal'),
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: buildSuccessContent(),
          );
        },
      ),
    )..show();
  }

  void _dismissDialog() {
    if (_dialog != null) {
      Navigator.of(context, rootNavigator: true).pop();
      _dialog = null;
    }
  }

  void _showErrorDialog(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: 'Kesalahan',
      desc: message,
      btnOkText: 'OK',
      btnOkOnPress: () {},
    ).show();
  }

  // Method to update delay information after successful download
  void updateDelayInfo(String delaySend, String delayServer, String delayClient, String delayTotal) {
    _delaySend = delaySend;
    _delayServer = delayServer;
    _delayClient = delayClient;
    _delayTotal = delayTotal;
    _showingDelayInfo = true;
    if (_isDownloadComplete && _dialogSetState != null) {
      _dialogSetState!(() {}); // Memicu rebuild dialog
    }
  }
}

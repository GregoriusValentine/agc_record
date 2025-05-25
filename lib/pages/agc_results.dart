import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:another_flushbar/flushbar.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/helper.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/loading.dart';
import 'fade_page_route.dart';

class AudioPair {
  final FileSystemEntity agcFile;
  final FileSystemEntity? originalFile;
  final String fileName;
  final String? formattedDate;

  AudioPair({
    required this.agcFile,
    this.originalFile,
    required this.fileName,
    this.formattedDate,
  });
}

class AgcResultsWidget extends StatefulWidget {
  final int selectedIndex;
  const AgcResultsWidget({super.key, required this.selectedIndex});

  @override
  State<AgcResultsWidget> createState() => _AgcResultsWidgetState();
}

class _AgcResultsWidgetState extends State<AgcResultsWidget> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<AudioPair> audioPairs = [];
  List<PlayerController> agcPlayerControllers = [];
  List<PlayerController> originalPlayerControllers = [];
  Map<String, int> fileToIndexMap = {};
  String? _playingAgcFilePath;
  String? _playingOriginalFilePath;
  bool isLoading = true;
  bool isRefreshing = false;
  bool isPausedAgc = false;
  bool isPausedOriginal = false;
  String searchQuery = '';
  String sortOrder = 'terbaru';
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<AudioPair> _filteredPairs = [];
  Timer? _debounce;
  var logger = Logger();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAudioFiles();
    _initializeAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _reinitializeState();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

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
    for (var controller in agcPlayerControllers) {
      controller.dispose();
    }
    for (var controller in originalPlayerControllers) {
      controller.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  Future<void> playAgcAudio(String path, int index) async {
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

      await agcPlayerControllers[index].setVolume(1.0);

      logger.i('Memulai pemutaran audio AGC');
      logger.i('Path: $path');
      logger.i('Index: $index');
      logger.i('Player controller state: ${agcPlayerControllers[index].playerState}');

      // If playing original audio, stop it first
      if (_playingOriginalFilePath != null) {
        final originalIndex = fileToIndexMap[_playingOriginalFilePath!];
        if (originalIndex != null) {
          await originalPlayerControllers[originalIndex].pausePlayer();
        }
        setState(() {
          _playingOriginalFilePath = null;
          isPausedOriginal = false;
        });
      }

      if (_playingAgcFilePath == path && isPausedAgc) {
        logger.i('Melanjutkan pemutaran AGC yang di-pause');
        await agcPlayerControllers[index].startPlayer(
            finishMode: FinishMode.loop
        );
        setState(() {
          isPausedAgc = false;
        });
      } else if (_playingAgcFilePath == path) {
        logger.i('Menghentikan pemutaran AGC');
        await agcPlayerControllers[index].pausePlayer();
        setState(() {
          isPausedAgc = true;
        });
      } else {
        logger.i('Memulai pemutaran AGC baru');
        if (_playingAgcFilePath != null) {
          final oldIndex = fileToIndexMap[_playingAgcFilePath!];
          if (oldIndex != null) {
            await agcPlayerControllers[oldIndex].pausePlayer();
          }
        }
        setState(() {
          _playingAgcFilePath = path;
          isPausedAgc = false;
        });

        await agcPlayerControllers[index].startPlayer(
            finishMode: FinishMode.loop
        );
      }
    } catch (e) {
      logger.e("Error saat memutar audio AGC", error: e);
    }
  }

  Future<void> playOriginalAudio(String path, int index) async {
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

      await originalPlayerControllers[index].setVolume(1.0);

      logger.i('Memulai pemutaran audio Original');
      logger.i('Path: $path');
      logger.i('Index: $index');
      logger.i('Player controller state: ${originalPlayerControllers[index].playerState}');

      // If playing AGC audio, stop it first
      if (_playingAgcFilePath != null) {
        final agcIndex = fileToIndexMap[_playingAgcFilePath!];
        if (agcIndex != null) {
          await agcPlayerControllers[agcIndex].pausePlayer();
        }
        setState(() {
          _playingAgcFilePath = null;
          isPausedAgc = false;
        });
      }

      if (_playingOriginalFilePath == path && isPausedOriginal) {
        logger.i('Melanjutkan pemutaran Original yang di-pause');
        await originalPlayerControllers[index].startPlayer(
            finishMode: FinishMode.loop
        );
        setState(() {
          isPausedOriginal = false;
        });
      } else if (_playingOriginalFilePath == path) {
        logger.i('Menghentikan pemutaran Original');
        await originalPlayerControllers[index].pausePlayer();
        setState(() {
          isPausedOriginal = true;
        });
      } else {
        logger.i('Memulai pemutaran Original baru');
        if (_playingOriginalFilePath != null) {
          final oldIndex = fileToIndexMap[_playingOriginalFilePath!];
          if (oldIndex != null) {
            await originalPlayerControllers[oldIndex].pausePlayer();
          }
        }
        setState(() {
          _playingOriginalFilePath = path;
          isPausedOriginal = false;
        });

        await originalPlayerControllers[index].startPlayer(
            finishMode: FinishMode.loop
        );
      }
    } catch (e) {
      logger.e("Error saat memutar audio Original", error: e);
    }
  }

  Future<void> deleteAudioPair(AudioPair audioPair, int index) async {
    try {
      // Delete AGC file
      await audioPair.agcFile.delete();

      // Delete original file if exists
      if (audioPair.originalFile != null) {
        await audioPair.originalFile!.delete();
      }

      if (mounted) {
        setState(() {
          audioPairs.removeAt(index);
          agcPlayerControllers.removeAt(index);
          originalPlayerControllers.removeAt(index);

          if (_playingAgcFilePath == audioPair.agcFile.path) {
            _playingAgcFilePath = null;
            isPausedAgc = false;
          }

          if (audioPair.originalFile != null && _playingOriginalFilePath == audioPair.originalFile!.path) {
            _playingOriginalFilePath = null;
            isPausedOriginal = false;
          }

          // Update fileToIndexMap
          fileToIndexMap.clear();
          for (int i = 0; i < audioPairs.length; i++) {
            fileToIndexMap[audioPairs[i].agcFile.path] = i;
            if (audioPairs[i].originalFile != null) {
              fileToIndexMap[audioPairs[i].originalFile!.path] = i;
            }
          }
        });

        Navigator.pushReplacement(
          context,
          FadePageRoute(
            page: BottomNavWidgets(initialIndex: widget.selectedIndex),
          ),
        );

        Flushbar(
          title: "File Dihapus",
          message: "File audio telah berhasil dihapus.",
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
      logger.e("Error saat menghapus file", error: e);
    }
  }

  bool _isValidAudioFile(String path) {
    final file = File(path);
    final extension = path.split('.').last.toLowerCase();
    return file.existsSync() && (extension == 'wav' || extension == 'mp3');
  }

  Future<void> _loadAudioFiles() async {
    try {
      final directory = await getExternalStorageDirectory();

      // AGC audio directory
      final agcDir = Directory('${directory!.path}/download/audioagc');

      // Original audio directory
      final originalDir = Directory('${directory.path}/MyRecordings');

      if (await agcDir.exists()) {
        final agcFiles = agcDir.listSync().where((file) => _isValidAudioFile(file.path)).toList();
        agcFiles.sort((a, b) {
          final aName = a.uri.pathSegments.last;
          final bName = b.uri.pathSegments.last;

          final aRaw = FileHelper.extractTanggalDanWaktu(aName);
          final bRaw = FileHelper.extractTanggalDanWaktu(bName);

          if (aRaw == null || bRaw == null) return 0;

          // Sort from newest to oldest
          return bRaw.compareTo(aRaw);
        });

        // Create list of AudioPair objects
        List<AudioPair> pairs = [];

        for (var agcFile in agcFiles) {
          final agcFileName = agcFile.uri.pathSegments.last;

          String nameOriginal = agcFileName.replaceFirst('agc_', '');
          FileSystemEntity? originalFile;
          if (await originalDir.exists()) {
            final originalPath = '${originalDir.path}/${nameOriginal}';
            final originalFileObj = File(originalPath);
            if (await originalFileObj.exists()) {
              originalFile = originalFileObj;
            }
          }

          // Extract date and time for display
          String? rawDateTime = FileHelper.extractTanggalDanWaktu(agcFileName);
          String? formattedDate = FileHelper.formatTanggalDenganWaktu(rawDateTime);

          // Create AudioPair
          pairs.add(AudioPair(
            agcFile: agcFile,
            originalFile: originalFile,
            fileName: agcFileName,
            formattedDate: formattedDate,
          ));
        }

        setState(() {
          audioPairs = pairs;

          // Create player controllers for both AGC and original audio
          agcPlayerControllers = List<PlayerController>.generate(
            audioPairs.length,
                (index) => PlayerController(),
          );

          originalPlayerControllers = List<PlayerController>.generate(
            audioPairs.length,
                (index) => PlayerController(),
          );

          // Create mapping from file paths to indices
          fileToIndexMap.clear();
          for (int i = 0; i < audioPairs.length; i++) {
            fileToIndexMap[audioPairs[i].agcFile.path] = i;
            if (audioPairs[i].originalFile != null) {
              fileToIndexMap[audioPairs[i].originalFile!.path] = i;
            }
          }
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

  Future<void> _initializePlayers() async {
    for (int i = 0; i < audioPairs.length; i++) {
      final agcFile = audioPairs[i].agcFile;
      final originalFile = audioPairs[i].originalFile;

      // Initialize AGC player controller
      if (await File(agcFile.path).exists()) {
        try {
          await agcPlayerControllers[i].preparePlayer(
            path: agcFile.path,
            shouldExtractWaveform: true,
            noOfSamples: 100,
            volume: 1.0,
          );

          agcPlayerControllers[i].onPlayerStateChanged.listen((state) {
            logger.i('AGC Player $i state changed to: $state');
          });

          logger.i('AGC Player berhasil diinisialisasi untuk file: ${agcFile.path}');
        } catch (e) {
          logger.e('Error saat inisialisasi AGC player: $e');
        }
      }

      // Initialize Original player controller if file exists
      if (originalFile != null && await File(originalFile.path).exists()) {
        try {
          await originalPlayerControllers[i].preparePlayer(
            path: originalFile.path,
            shouldExtractWaveform: true,
            noOfSamples: 100,
            volume: 1.0,
          );

          originalPlayerControllers[i].onPlayerStateChanged.listen((state) {
            logger.i('Original Player $i state changed to: $state');
          });

          logger.i('Original Player berhasil diinisialisasi untuk file: ${originalFile.path}');
        } catch (e) {
          logger.e('Error saat inisialisasi Original player: $e');
        }
      }
    }
  }

  Future<void> _reinitializeState() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Stop all ongoing playback
      if (_playingAgcFilePath != null) {
        final agcIndex = fileToIndexMap[_playingAgcFilePath];
        if (agcIndex != null) {
          await agcPlayerControllers[agcIndex].pausePlayer();
        }
      }

      if (_playingOriginalFilePath != null) {
        final originalIndex = fileToIndexMap[_playingOriginalFilePath];
        if (originalIndex != null) {
          await originalPlayerControllers[originalIndex].pausePlayer();
        }
      }

      // Dispose all player controllers
      for (var controller in agcPlayerControllers) {
        controller.dispose();
      }

      for (var controller in originalPlayerControllers) {
        controller.dispose();
      }

      // Reset state
      agcPlayerControllers = [];
      originalPlayerControllers = [];
      _playingAgcFilePath = null;
      _playingOriginalFilePath = null;
      isPausedAgc = false;
      isPausedOriginal = false;
      _filteredPairs = [];

      // Reload audio files
      await _loadAudioFiles();
    } catch (e) {
      logger.e("Error saat menginisialisasi ulang state", error: e);
    } finally {
      setState(() {
        isLoading = false;
      });
      _updateFilteredPairs();
    }
  }

  void _updateFilteredPairs() {
    var filtered = audioPairs.where((pair) {
      final fileName = pair.fileName.toLowerCase();
      final searchTerms = searchQuery.toLowerCase().split(' ');
      return searchTerms.every((term) => fileName.contains(term));
    }).toList();

    if (sortOrder == 'terbaru') {
      filtered.sort((a, b) {
        final aName = a.fileName;
        final bName = b.fileName;

        final aRaw = FileHelper.extractTanggalDanWaktu(aName);
        final bRaw = FileHelper.extractTanggalDanWaktu(bName);

        if (aRaw == null || bRaw == null) return 0;

        // Newest to oldest
        return bRaw.compareTo(aRaw);
      });
    } else {
      filtered.sort((a, b) {
        final aName = a.fileName;
        final bName = b.fileName;

        final aRaw = FileHelper.extractTanggalDanWaktu(aName);
        final bRaw = FileHelper.extractTanggalDanWaktu(bName);

        if (aRaw == null || bRaw == null) return 0;

        // Oldest to newest
        return aRaw.compareTo(bRaw);
      });
    }

    setState(() {
      _filteredPairs = filtered;
    });
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        searchQuery = value;
      });
      _updateFilteredPairs();
    });
  }

  List<AudioPair> get filteredAndSortedPairs {
    if (_filteredPairs.isEmpty) {
      _updateFilteredPairs();
    }
    return _filteredPairs;
  }

  void _showConfirmDelete(BuildContext context, AudioPair audioPair, int index, String name) async {
    // Pause any playing audio
    if (_playingAgcFilePath == audioPair.agcFile.path) {
      await agcPlayerControllers[index].pausePlayer();
      setState(() {
        isPausedAgc = true;
      });
    } else if (_playingAgcFilePath != null) {
      final oldIndex = fileToIndexMap[_playingAgcFilePath!];
      if (oldIndex != null) {
        await agcPlayerControllers[oldIndex].pausePlayer();
      }
    }

    if (audioPair.originalFile != null && _playingOriginalFilePath == audioPair.originalFile!.path) {
      await originalPlayerControllers[index].pausePlayer();
      setState(() {
        isPausedOriginal = true;
      });
    } else if (_playingOriginalFilePath != null) {
      final oldIndex = fileToIndexMap[_playingOriginalFilePath!];
      if (oldIndex != null) {
        await originalPlayerControllers[oldIndex].pausePlayer();
      }
    }

    AwesomeDialog(
      context: context,
      customHeader: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final isDeleteIcon = _animation.value < 0.5;
          final iconColor = isDeleteIcon ? Colors.red : Colors.deepPurple;
          final borderColor = isDeleteIcon ? Colors.red : Colors.deepPurple;

          return Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: borderColor,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(
              isDeleteIcon ? Icons.delete_outline : Icons.question_mark_rounded,
              color: iconColor,
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
        deleteAudioPair(audioPair, index);
      },
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    var isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final loadingWidget = Loading().buildEmptyState(
        height,
        width,
        isLandscape,
        _animationController,
        _animation,
        searchQuery.isEmpty ? "Belum Ada File Audio" : "Data tidak ditemukan"
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: const Text(
          'AGC Results',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                              fontWeight: sortOrder == 'terbaru' ? FontWeight.bold : FontWeight.normal,
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                              fontWeight: sortOrder == 'terlama' ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
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
              child: filteredAndSortedPairs.isEmpty
                  ? loadingWidget
                  : ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                scrollDirection: Axis.vertical,
                itemCount: filteredAndSortedPairs.length,
                itemBuilder: (context, index) {
                  final audioPair = filteredAndSortedPairs[index];
                  final originalIndex = fileToIndexMap[audioPair.agcFile.path] ?? 0;
                  final agcPlayerController = agcPlayerControllers[originalIndex];
                  final originalPlayerController = originalPlayerControllers[originalIndex];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    audioPair.formattedDate!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    _showConfirmDelete(
                                        context,
                                        audioPair,
                                        originalIndex,
                                        audioPair.fileName
                                    );
                                  },
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  color: Colors.redAccent,
                                ),
                              ],
                            ),
                          ),
                          Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                title: Text(
                                  audioPair.fileName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                collapsedBackgroundColor: Colors.transparent,
                                backgroundColor: Colors.transparent,
                                children: [
                                  // AGC Audio Player
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blue[200]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "AGC Audio",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueAccent,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            // Play/pause button
                                            Container(
                                              height: 44,
                                              width: 44,
                                              decoration: BoxDecoration(
                                                color: _playingAgcFilePath == audioPair.agcFile.path
                                                    ? Colors.blueAccent
                                                    : Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.1),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: IconButton(
                                                icon: Icon(
                                                  _playingAgcFilePath == audioPair.agcFile.path && !isPausedAgc
                                                      ? Icons.pause
                                                      : Icons.play_arrow,
                                                  color: _playingAgcFilePath == audioPair.agcFile.path
                                                      ? Colors.white
                                                      : Colors.blueAccent,
                                                  size: 24,
                                                ),
                                                onPressed: () {
                                                  playAgcAudio(audioPair.agcFile.path, originalIndex);
                                                },
                                                padding: EdgeInsets.zero,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Waveform
                                            Expanded(
                                              child: AudioFileWaveforms(
                                                playerController: agcPlayerController,
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
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Original Audio Player (if exists)
                                  if (audioPair.originalFile != null)
                                  Container(
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.green[200]!),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Original Audio",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              // Play/pause button
                                              Container(
                                                height: 44,
                                                width: 44,
                                                decoration: BoxDecoration(
                                                  color: _playingOriginalFilePath == audioPair.originalFile!.path
                                                      ? Colors.green
                                                      : Colors.white,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.1),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: IconButton(
                                                  icon: Icon(
                                                    _playingOriginalFilePath == audioPair.originalFile!.path && !isPausedOriginal
                                                        ? Icons.pause
                                                        : Icons.play_arrow,
                                                    color: _playingOriginalFilePath == audioPair.originalFile!.path
                                                        ? Colors.white
                                                        : Colors.green,
                                                    size: 24,
                                                  ),
                                                  onPressed: () {
                                                    playOriginalAudio(audioPair.originalFile!.path, originalIndex);
                                                  },
                                                  padding: EdgeInsets.zero,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // Waveform
                                              Expanded(
                                                child: AudioFileWaveforms(
                                                  playerController: originalPlayerController,
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
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                          )
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
      floatingActionButton: isLoading
          ? null
          : FloatingActionButton(
        onPressed: _reinitializeState,
        child: const Icon(Icons.refresh),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      )
    );
  }
}
import 'dart:async';
import 'dart:math';

import 'package:another_flushbar/flushbar.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';

class AgcResult {
  final int id;
  final String originalFile;
  final String processedFile;
  final String plotData;
  final String originalUrl;
  final String processedUrl;
  final double timestamp;

  AgcResult({
    required this.id,
    required this.originalFile,
    required this.processedFile,
    required this.plotData,
    required this.originalUrl,
    required this.processedUrl,
    required this.timestamp,
  });

  factory AgcResult.fromJson(Map<String, dynamic> json) {
    return AgcResult(
      id: json['id'],
      originalFile: json['original_file'],
      processedFile: json['processed_file'],
      plotData: json['plot_data'],
      originalUrl: json['original_url'],
      processedUrl: json['processed_url'],
      timestamp: json['timestamp'],
    );
  }
}

class AgcResultsWidget extends StatefulWidget {
  const AgcResultsWidget({super.key});

  @override
  State<AgcResultsWidget> createState() => _AgcResultsWidgetState();
}

class _AgcResultsWidgetState extends State<AgcResultsWidget> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<AgcResult> results = [];
  bool isLoading = true;
  bool isRefreshing = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isVisible = true;
  double lastTimestamp = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimation();
    fetchResults();
  }

    @override
    void didChangeAppLifecycleState(AppLifecycleState state) {
      super.didChangeAppLifecycleState(state);
      _isVisible = state == AppLifecycleState.resumed;
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
    _animationController.dispose();
    super.dispose();
  }

  Future<void> fetchResults() async {
    if (!isRefreshing) {
      setState(() {
        isLoading = true;
      });
    }
    try {
      final response = await http.get(
        Uri.parse('https://agcrecord.batutech.cloud/api/agc-results?last_timestamp=$lastTimestamp'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<AgcResult> newResults = (data['data'] as List)
              .map((item) => AgcResult.fromJson(item))
              .toList();
          
          setState(() {
            results.addAll(newResults);
            if (newResults.isNotEmpty) {
              lastTimestamp = newResults.map((r) => r.timestamp).reduce(max);
            }
            isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load results');
      }
    } catch (e) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });
      }
    }
  }

  String formatTime(Duration duration) {
    String twoDigital(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigital(duration.inHours);
    final minutes = twoDigital(duration.inMinutes.remainder(60));
    final seconds = twoDigital(duration.inSeconds.remainder(60));

    return [
      if (duration.inHours > 0) hours,
      minutes,
      seconds,
    ].join(':');
  }

  Future<void> _refreshData() async {
    setState(() {
      isRefreshing = true;
    });
    await fetchResults();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    var isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: const Text(
          'AGC Results',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Stack(
          children: [
            if (results.isEmpty && !isLoading)
              _buildEmptyState(height, width, isLandscape)
            else if (!isLoading)
              ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final result = results[index];
                  return AudioCard(result: result);
                },
              ),
            if (isLoading && !isRefreshing)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(double height, double width, bool isLandscape) {
    return ListView(
      children: [
        SizedBox(height: isLandscape ? height * 0.2 : height * 0.3),
        Center(
          child: SizedBox(
            width: width * 0.5,
            height: isLandscape ? height * 0.25 : height * 0.15,
            child: Opacity(
              opacity: 0.3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final isAnimatedIcon = _animation.value < 0.5;
                      final iconColor = isAnimatedIcon ? Colors.blue : Colors.deepPurple;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: iconColor,
                            width: 2,
                          ),
                        ),
                        padding: isLandscape ? const EdgeInsets.all(10) : const EdgeInsets.all(20),
                        child: Icon(
                          isAnimatedIcon ? Icons.search_off_rounded : Icons.search,
                          color: iconColor,
                          size: isLandscape ? 40 : 50,
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final isAnimatedIcon = _animation.value < 0.5;
                      final textColor = isAnimatedIcon ? Colors.blue : Colors.deepPurple;

                      return Text(
                        "Blank AGC Results",
                        style: TextStyle(
                          color: textColor,
                          fontSize: isLandscape ? 15 : 20,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AudioCard extends StatefulWidget {
  final AgcResult result;

  const AudioCard({super.key, required this.result});

  @override
  State<AudioCard> createState() => _AudioCardState();
}

class _AudioCardState extends State<AudioCard> {
  final audioPlayer = AudioPlayer();
  bool isPlayingOriginal = false;
  bool isPlayingProcessed = false;
  bool isExpanded = false;
  bool isLoadingOriginal = false; // Loading untuk original audio
  bool isLoadingProcessed = false; // Loading untuk processed audio
  Duration duration = Duration.zero;
  Duration positionOriginal = Duration.zero;
  Duration positionProcessed = Duration.zero;
  String? plotData;

  @override
  void initState() {
    super.initState();
    plotData = widget.result.plotData; 
    
    audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        isPlayingOriginal = state == PlayerState.playing && isPlayingOriginal;
        isPlayingProcessed = state == PlayerState.playing && isPlayingProcessed;

        if (state == PlayerState.playing) {
          isLoadingOriginal = false;
          isLoadingProcessed = false;
        }
      });
    });

    audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() {
        duration = newDuration;
      });
    });

    audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() {
        if (isPlayingOriginal) {
          positionOriginal = newPosition;
        } else if (isPlayingProcessed) {
          positionProcessed = newPosition;
        }
      });
    });

    audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        if (isPlayingOriginal) {
          positionOriginal = Duration.zero;
          isPlayingOriginal = false;
        } else if (isPlayingProcessed) {
          positionProcessed = Duration.zero;
          isPlayingProcessed = false;
        }
      });
    });
  }

  @override
  void dispose() {
    audioPlayer.stop();
    audioPlayer.dispose();
    super.dispose();
  }

  String formatTime(Duration duration) {
    String twoDigital(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigital(duration.inHours);
    final minutes = twoDigital(duration.inMinutes.remainder(60));
    final seconds = twoDigital(duration.inSeconds.remainder(60));

    return [
      if (duration.inHours > 0) hours,
      minutes,
      seconds,
    ].join(':');
  }

  Future<void> _deleteAudio() async {
    try {
      var log = Logger();
      final response = await http.delete(
        Uri.parse('https://agcrecord.batutech.cloud/api/delete-audio/${widget.result.originalFile}'),
      );
      log.i('${response.statusCode}');
      if (response.statusCode == 200) {
        if (mounted) {


          // Hapus item dari list
          final agcResultsState = context.findAncestorStateOfType<_AgcResultsWidgetState>();
          if (agcResultsState != null) {
            agcResultsState.setState(() {
              agcResultsState.results.removeWhere(
                (r) => r.originalFile == widget.result.originalFile
              );
            });
          }
          
          _showSuccessDialog();
        }
      } else {
        throw Exception('Failed to delete audio');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to delete audio: $e');
      }
    }
  }

  void _showDeleteConfirmation() {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.bottomSlide,
      title: 'Delete Audio',
      desc: 'Are you sure you want to delete this audio?',
      btnCancelOnPress: () {},
      btnOkOnPress: () {
        _deleteAudio();
      },
      btnCancelText: 'Cancel',
      btnOkText: 'Delete',
      btnOkColor: Colors.red,
    ).show();
  }

  void _showSuccessDialog() {
    if (!mounted) return;
    Flushbar(
      title: "Success",
      message: "Audio deleted successfully.",
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

  void _showErrorDialog(String errorMessage) {
    if (!mounted) return;

    Flushbar(
      title: "Error",
      message: "${errorMessage}",
      duration: const Duration(seconds: 1),
      backgroundColor: Colors.red,
      icon: const Icon(
        Icons.error,
        color: Colors.white,
      ),
      flushbarPosition: FlushbarPosition.TOP,
      flushbarStyle: FlushbarStyle.FLOATING,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
    ).show(context);
  }


  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: Colors.grey[700],
      child: ExpansionTile(
        collapsedShape: const RoundedRectangleBorder(
            side: BorderSide.none,
        ),
        shape: const RoundedRectangleBorder(
          side: BorderSide.none,
        ),
        title: Text(
          widget.result.originalFile,
          style: const TextStyle(color: Colors.white),
        ),
        collapsedIconColor: Colors.white,
        iconColor: Colors.white,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 13.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: plotData != null
                    ? Image.memory(
                        base64Decode(plotData!),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : Container(),
                ),
                _buildAudioPlayer(
                  title: 'Before AGC',
                  url: 'https://agcrecord.batutech.cloud${widget.result.originalUrl}',
                  isPlaying: isPlayingOriginal,
                  position: positionOriginal,
                ),
                _buildAudioPlayer(
                  title: 'After AGC',
                  url: 'https://agcrecord.batutech.cloud${widget.result.processedUrl}',
                  isPlaying: isPlayingProcessed,
                  position: positionProcessed,
                ),
              ],
            ),
          ),
        ],
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _showDeleteConfirmation,
            ),
            const Icon(Icons.expand_more, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer({
    required String title,
    required String url,
    required bool isPlaying,
    required Duration position,
  }) {
    bool isOriginal = url.contains(widget.result.originalUrl);
    bool isLoading = isOriginal ? isLoadingOriginal : isLoadingProcessed;

    return Card(
      margin: const EdgeInsets.only(bottom: 13.0),
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.only(right: 13.0, bottom: 13.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20.0, top: 20.0),
              child: Text(
                title,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: isLoading 
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white
                        ),
                  onPressed: isLoadingOriginal || isLoadingProcessed
                      ? null 
                      : () async {
                          if (isPlaying) {
                            await audioPlayer.pause();
                            setState(() {
                              isPlayingOriginal = false;
                              isPlayingProcessed = false;
                            });
                          } else {
                            setState(() {
                              if (isOriginal) {
                                isLoadingOriginal = true;
                              } else {
                                isLoadingProcessed = true;
                              }
                            });
                            try {
                              // Stop other playback first
                              if (isPlayingOriginal || isPlayingProcessed) {
                                await audioPlayer.stop();
                              }
                              await audioPlayer.play(UrlSource(url));
                              setState(() {
                                isPlayingOriginal = isOriginal;
                                isPlayingProcessed = !isOriginal;
                              });
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error playing audio: $e')),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  if (isOriginal) {
                                    isLoadingOriginal = false;
                                  } else {
                                    isLoadingProcessed = false;
                                  }
                                });
                              }
                            }
                          }
                        },
                ),
                Text(
                  formatTime(position),
                  style: const TextStyle(color: Colors.white),
                ),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: duration.inSeconds.toDouble(),
                    value: position.inSeconds.toDouble(),
                    onChanged: (value) async {
                      final newPosition = Duration(seconds: value.toInt());
                      await audioPlayer.seek(newPosition);
                      setState(() {
                        if (isPlayingOriginal) {
                          positionOriginal = newPosition;
                        } else if (isPlayingProcessed) {
                          positionProcessed = newPosition;
                        }
                      });
                    },
                  ),
                ),
                Text(
                  formatTime(duration - position),
                  style: const TextStyle(color: Colors.white)
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
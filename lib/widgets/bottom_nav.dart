import 'package:agc_record/pages/recording.dart';
import 'package:agc_record/pages/agc_results.dart';
import 'package:agc_record/pages/recording_results.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';

class BottomNavWidgets extends StatefulWidget {
  final int initialIndex;
  const BottomNavWidgets({super.key, this.initialIndex = 0});

  @override
  State<BottomNavWidgets> createState() => _BottomNavWidgetsState();
}

class _BottomNavWidgetsState extends State<BottomNavWidgets> {
  late int selectedIndex;
  late PageController pageController;
  bool _isRecording = false;


  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    pageController = PageController(initialPage: selectedIndex);
    pageController.addListener(() {
      setState(() {
        selectedIndex = pageController.page!.toInt();
      });
    });
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void onTapped(int index) {
    if(_isRecording){
      Flushbar(
        title: "Masih Merekam",
        message: "Jika Anda ingin berpindah halaman, selesaikan rekaman terlebih dahulu.",
        duration: const Duration(seconds: 2), // Increased duration to ensure visibility
        backgroundColor: Colors.green,
        icon: const Icon(
          Icons.av_timer_rounded,
          color: Colors.white,
        ),
        flushbarPosition: FlushbarPosition.TOP,
        flushbarStyle: FlushbarStyle.FLOATING,
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(8),
      ).show(context);
    }else{
      setState((){
        selectedIndex = index;
      });
      pageController.jumpToPage(index);
    }
  }

  void _updateRecordingStatus(bool isRecording) {
    setState(() {
      _isRecording = isRecording;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          RecordingWidget(onRecordingStatusChange: _updateRecordingStatus),
          const RecordingResultsWidget(selectedIndex: 1),
          const AgcResultsWidget()
        ],
      ),
      bottomNavigationBar: NavigationBar(
        indicatorColor: Colors.blue,
        selectedIndex: selectedIndex,
        onDestinationSelected: onTapped,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            selectedIcon: Icon(Icons.mic_rounded),
            icon: Icon(
              Icons.mic_none_rounded,
              color: Colors.green,
            ),
            label: 'Recording',
          ),
          NavigationDestination(
            selectedIcon: Icon(
              Icons.cloud_upload_rounded
            ),
            icon: Icon(
              Icons.cloud_upload_outlined,
              color: Colors.green,
            ),
            label: 'Recording Results',
          ),
          NavigationDestination(
            selectedIcon: Icon(
              Icons.my_library_music_rounded
            ),
            icon: Icon(
              Icons.my_library_music_outlined,
              color: Colors.green,
            ),
            label: 'AGC Results',
          ),
        ], 
      ),
    );
  }
} 
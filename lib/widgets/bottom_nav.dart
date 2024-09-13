import 'package:agc_record/pages/recording.dart';
import 'package:agc_record/pages/ACG_results.dart';
import 'package:agc_record/pages/recording_results.dart';
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


  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    pageController = PageController(initialPage: selectedIndex);
    // Listen to page changes to update selected index
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

  // Function pindah tab
  void onTapped(int index) {
    setState((){
      selectedIndex = index;
    });
    pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          RecordingWidget(),
          RecordingResultsWidget(selectedIndex: 1),
          AgcResultsWidget()
        ],
      ),
      bottomNavigationBar: NavigationBar(
        indicatorColor: Colors.blue,
        selectedIndex: selectedIndex,
        onDestinationSelected: onTapped,
        destinations: const <Widget>[
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
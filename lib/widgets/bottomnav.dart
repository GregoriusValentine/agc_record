import 'package:agc_record/pages/record.dart';
import 'package:agc_record/pages/result.dart';
import 'package:agc_record/pages/share.dart';
import 'package:flutter/material.dart';

class BottomNavWidgets extends StatefulWidget {
  const BottomNavWidgets({super.key});

  @override
  State<BottomNavWidgets> createState() => _BottomNavWidgetsState();
}

class _BottomNavWidgetsState extends State<BottomNavWidgets> {
  int selectedIndex = 0;
  PageController pageController = PageController();
  String audioPath = '';

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
          recordWidget(),
          shareWidget(),
          resultWidget()
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
            label: 'Record',
          ),
          NavigationDestination(
            selectedIcon: Icon(
              Icons.cloud_upload_rounded
            ),
            icon: Icon(
              Icons.cloud_upload_outlined,
              color: Colors.green,
            ),
            label: 'Result Record',
          ),
          NavigationDestination(
            selectedIcon: Icon(
              Icons.my_library_music_rounded
            ),
            icon: Icon(
              Icons.my_library_music_outlined,
              color: Colors.green,
            ),
            label: 'Result AGC',
          ),
        ], 
      ),
    );
  }
} 
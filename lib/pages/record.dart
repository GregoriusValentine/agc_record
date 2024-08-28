import 'package:flutter/material.dart';

class recordWidget extends StatefulWidget {
  const recordWidget({super.key});

  @override
  State<recordWidget> createState() => _recordWidgetState();
}

class _recordWidgetState extends State<recordWidget> {
  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Text(
          'Record',
          style: TextStyle(
            color: Colors.white
          ),
        ),
      ),
      body: Container(
        child: Center(
          child: Container(
            height: height * 0.50,
            child: Column(
              children: [
                Container(
                  child: Container(
                    height: height*0.18,
                    child: Center(
                      child: Container(
                        child: Text(
                          '00:00:00',
                          style: TextStyle(
                            fontSize: 50,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  child: Container(
                    height: height*0.14,
                    // color: Colors.blue,
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            'Tombol Rekam Suara',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500
                            ),
                          ),
                          SizedBox(
                            height: 15,
                          ),
                          Center(
                            child: Ink(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle, // Bentuk lingkaran untuk container
                                color: Color.fromARGB(255, 250, 103, 66),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.6), // Warna bayangan
                                    spreadRadius: 0, // Seberapa jauh bayangan menyebar
                                    blurRadius: 6, // Seberapa lembut bayangan
                                    offset: Offset(1, 1), // Posisi bayangan (kanan bawah)
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.mic_rounded,
                                  size: 50,
                                  color: Colors.black,
                                ),
                                color: Colors.white,
                                onPressed: () {},
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  child: Container(
                    height: height*0.18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
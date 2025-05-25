import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Loading {
  Widget buildEmptyState(
      double height,
      double width,
      bool isLandscape,
      AnimationController animationController,
      Animation<double> animation,
      String teksPesan,
      ) {
    return ListView(
      children: [
        SizedBox(height: isLandscape ? height * 0.2 : height * 0.2),
        Center(
          child: SizedBox(
            width: width * 0.5,
            height: isLandscape ? height * 0.25 : height * 0.25,
            child: Opacity(
              opacity: 0.3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: animationController,
                    builder: (context, child) {
                      final isAnimatedIcon = animation.value < 0.5;
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
                    animation: animationController,
                    builder: (context, child) {
                      final isAnimatedIcon = animation.value < 0.5;
                      final textColor = isAnimatedIcon ? Colors.blue : Colors.deepPurple;

                      return Text(
                        teksPesan,
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
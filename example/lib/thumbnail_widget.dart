import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

 /// Display the thumbnail of the captured image or video.
class ThumbnailWidget extends StatelessWidget {

  final VideoPlayerController videoPlayerController;
  final String imagePath;

  const ThumbnailWidget({Key key, this.videoPlayerController, this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
        alignment: Alignment.centerRight,
        child: 
            videoPlayerController == null && imagePath == null
                ? Container()
                : SizedBox(
                    child: (videoPlayerController == null)
                        ? Image.file(File(imagePath))
                        : Container(
                            child: Center(
                              child: AspectRatio(
                                  aspectRatio:
                                      videoPlayerController.value.size != null
                                          ? videoPlayerController.value.aspectRatio
                                          : 1.0,
                                  child: VideoPlayer(videoPlayerController)),
                            ),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.pink)),
                          ),
                    width: 120.0,
                    height: 120.0,
                  ),
         
      
    );
  }
}
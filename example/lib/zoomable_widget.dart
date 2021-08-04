import 'dart:async';
import 'package:flutter/material.dart';

class ZoomableWidget extends StatefulWidget {
  final Widget child;
  final Function onZoom;

  const ZoomableWidget({Key key, this.child, this.onZoom})
      : super(key: key);

  @override
  _ZoomableWidgetState createState() => _ZoomableWidgetState();
}

class _ZoomableWidgetState extends State<ZoomableWidget> {
  //Matrix4 matrix = Matrix4.identity();
  //double zoom = 1;
  //double prevZoom = 1;

  //zoomIn & zoomOut
  double previousPosX = -1.0;
  double previousPosY = -1.0;

  double previousZoom = 0.0;


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      //new zoom
      onVerticalDragUpdate: (DragUpdateDetails details) {
            double dragDistance;
            double facteur = 0.005;
            if (previousPosX > 0.0 && previousPosY > 0.0) 
            {
              dragDistance = ((details.globalPosition.dx - previousPosX) + (details.globalPosition.dy-previousPosY))*-1;
              print("distance: "+dragDistance.toString());
            }
            previousPosX = details.globalPosition.dx;
            previousPosY = details.globalPosition.dy;
             if (dragDistance > 0) {
               print("top drag");
               print(facteur * dragDistance);
               previousZoom = previousZoom + ((facteur * dragDistance)).clamp(0.01, 0.99);
               print("aaa up: "+previousZoom.toString());
               widget.onZoom(previousZoom.clamp(1, 4));
               setState(() {
                 
               });
            } else {
              print("bottom drag");
              print(facteur * dragDistance);
              previousZoom = previousZoom - ((facteur * dragDistance)).clamp(0.01, 0.99);
              print("aaa down: "+previousZoom.toString());
              widget.onZoom(previousZoom.clamp(1, 4));
              setState(() {
                
              });
            }
            
          },
          onVerticalDragEnd: (DragEndDetails details) {
            previousPosX = -1.0;
            previousPosY = -1.0;
          },
        //
        child: Stack(children: [
          Column(
            children: <Widget>[
              Container(
                child: Expanded(
                  child: widget.child,
                ),
              ),
            ],
          ),
        ]));
  }
}

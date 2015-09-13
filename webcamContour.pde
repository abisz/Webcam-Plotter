/*
 *  WebcamContour
 *  Author: Simon Reinsperger
 *  This programm captures an image from a webcam, uses opencv to convert it to a 
 *  black and white image, detects the contours and sends the data of the point of
 *  the contour to a arduino, which will draw the picture.
 *  
 *  CONTROLS:
 *  UP - captures or updates image
 *  DOWN - changes viewmode between captured image and live camera feed
 *  RIGHT - increases treshold
 *  LEFT - decreases treshold
 *  ALT - increases Smoothness
 *  CTRL - decreases Smoothness
 *  + - increases detailTresh
 *  - - decreases detailTresh
 *  b - changes backgroundMode
 *  p - starts drawing mode
 *  s - saves image into the program folder (!! OVERWRITES EXISTING ONES !!)
 */

//importing libraries
import processing.video.*;
import gab.opencv.*;
import processing.serial.*;

//declaring cam
Capture cam;

//declaring Serial port
Serial myPort;

//declaring openCV, PImage and ArrayList for Contours
OpenCV opencv;
PImage src;
ArrayList<Contour> contours;

//boolean to save whether a image is taken from the cam or not
boolean captured = false;

//some variables for adjusting the image
int treshold = 70;
double smoothValue = 1;
int detailTresh = 1;
boolean blkBgr = true;

//sets drawStart to true inside draw
boolean draw = false;
//to make sure the drawing starts at the beginning of a draw loop and not during one
boolean drawStart = false;
//to make sure the first point of a contour is not drawn to
boolean first = true;
//save old position to calculate the distance and set the delay accordingly
float oldX;
float oldY;
//delayFactor
int delayFactor = 35;
int minDelay = 250;
int maxDelay = 2500;
//saving if last point was out of frame
boolean outOfFrame = false;
//counts points per contour
int counter = 0;

void setup() {
  size(512, 512);

  myPort = new Serial(this, Serial.list()[2], 9600);

  src = new PImage(width, height, RGB);

  //getting all cams available
  String[] cameras = Capture.list();

  //println all cams available
  if (cameras.length == 0) {
    println("There are no cameras available for capture.");
    exit();
  } else {
    println("Available cameras:");
    for (int i = 0; i < cameras.length; i++) {
      println(cameras[i]);
    }

    //initializing Cam
    cam = new Capture(this, cameras[4]);
    cam.start();
  }
}

void draw() {

  //making sure draw gets set to true at the beginning of a frame
  if (draw) drawStart = true;
  draw = false;

  if (cam.available() == true) {
    cam.read();
  }
  //if an image is captured
  if (captured) {

    //check if the background should be seen or not 
    if (blkBgr) image(src, 0, 0);
    else background(255);

    //foreach contour
    for (Contour contour : contours) {

      //smooth the contour by setting the polygonApproximationFactor to the smoothValue
      contour.setPolygonApproximationFactor((double)smoothValue);

      //colour the contour on screen red
      stroke(255, 0, 0);

      //don't do anything if area of contour is too small
      if (contour.area() > detailTresh) {
        //beginn a new shape
        beginShape();
        //foreach point of the contour
        for (PVector point : contour.getPolygonApproximation ().getPoints()) {
          //add vertex to the shape
          vertex(point.x, point.y);

          //if the picture should be drawn
          if (drawStart) {

            //calculating distance to previous point
            int diff = (int) (Math.sqrt(Math.pow(abs(oldX-point.x), 2) + (Math.pow(abs(oldY-point.y), 2))));
            //setting delay in a certain range depending on distance
            int delay = diff*delayFactor;
            if (delay<minDelay) delay = minDelay;
            if (delay>maxDelay) delay = maxDelay;

            //check if point is out of frame - don't draw!
            if (point.x>512 || point.y > 512) {
              println("Out of frame (" + counter + ")");
              outOfFrame = true;
            } else if (outOfFrame) {
              //if the last point was out of frame the next should not be drawn because that could lead to some strange lines across the picture
              // instead move to the current point
              communicate(0, floor(point.x), floor(point.y));
              //some extra delay, maybe not necessary, but for security
              delay(delay+250);
              outOfFrame = false;
            } else if (first) {
              //the first point of a contour should also not be drawn.
              communicate(0, floor(point.x), floor(point.y));
              delay(delay);
              println(delay);
              first = false;
            } else {
              //actuall drawing
              communicate(1, floor(point.x), floor(point.y));
              delay(delay);
              println(delay);
            }
            
            //saving point to calculate distance for the next point
            oldX = point.x;
            oldY = point.y;
            //updating counter
            counter++;
          }//if-drawStart
        }//for:points

        //ends shape (= contour)
        endShape();
        //reseting counter
        counter=0;
        //reseting first
        first = true;
      }//detailTrash
    }//for:Contour
    
    //move to original position and feedback the end
    if (drawStart) {
      println("FINISHED!");
      communicate(2, 0, 0);
      drawStart = false;
    }
  }//if-captured
  //if no image is captured show the cam input
  else {
    image(cam, 0, 0);
  }
}

void keyPressed() {
  if (key == CODED) {
    if (keyCode == UP) {
      //"make" photo or updates if there is one
      src = cam.get();
      opencv = new OpenCV(this, src); 
      updateContours(); 
      captured = true;
    } else if (keyCode == DOWN) {
      //changes viewmode ( actual webcam footage ) the old pic doesn't get overwritten
      captured = !captured;
    } else if (keyCode == RIGHT) {
      //increasing treshold
      treshold+=5; 
      updateContours();
    } else if (keyCode == LEFT) {
      //decreasing treshold, making sure it's not getting negativ
      treshold--; 
      if(treshold<=0) treshold = 0;
      updateContours();
    } else if (keyCode == ALT) {
      //increasing smoothness
      smoothValue=smoothValue + 0.1;
    } else if (keyCode == CONTROL) {
      //decreasing smoothness, making sure it's not getting negativ
      smoothValue=smoothValue - 0.1;
      if (smoothValue <= 0) smoothValue = 0;
    }
  } else if (key == 'b' || key == 'B') {
    //changing backgroundMode
    blkBgr = !blkBgr;
  } else if (key == '+') {
    //increasing treshold for details
    detailTresh++;
  } else if (key == '-') {
    //decreasing treshold for details, minimum 1
    detailTresh--; 
    if (detailTresh<=0) detailTresh=1;
  } else if (key == 'p' && captured) {
    //set drawing mode to true, picture has to be captured before this is possible
    draw = true;
  } else if (key == 'q') {
    //move to start position, mainly a debug feature, there is no scenario left to need this
    communicate(2, 0, 0);
  } else if (key == 's') {
    //save image digitally
    if (blkBgr) {
      save("black.jpg");
    } else {
      save("contour.jpg");
    }
  }
}

//updates openCV opject (gets called when changing the treshold)
void updateContours() {
  opencv.gray(); 
  opencv.threshold(treshold); 
  src = opencv.getOutput(); 

  contours = opencv.findContours();
}

//function to communicate with arduino script
//x and y get split up in bytes to transmit, maybe not the most elegant way to do this, but it works!
//this code limits the size of x and y to 512
void communicate(int type, int x, int y) {
  //0-512 (4byte) for Xaxis
  //0-512 (4byte) for YAxis
  int x1 = x;
  int x2 = 0;
  int x3 = 0;
  int x4 = 0;

  int y1 = y;
  int y2 = 0;
  int y3 = 0;
  int y4 = 0;
  int y5 = 0;

  if (x1>128) {
    x2 = x1-128;
    x1 = 128;
  }
  if (x2>128) {
    x3 = x2-128;
    x2 = 128;
  }
  if (x3>128) {
    x4 = x3-128;
    x3 = 128;
  }


  if (y1>128) {
    y2 = y1-128;
    y1 = 128;
  }
  if (y2>128) {
    y3 = y2-128;
    y2 = 128;
  }
  if (y3>128) {
    y4 = y3-128;
    y3 = 128;
  }


  byte[] message = {
    (byte)type, 
    (byte)x1, 
    (byte)x2, 
    (byte)x3, 
    (byte)x4, 
    (byte)y1, 
    (byte)y2, 
    (byte)y3, 
    (byte)y4
  };

  myPort.write(message);
}


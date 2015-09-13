/*
 *  Hardware Control for X/Y- Plotter
 *  Author: Simon Reinsperger
 *  This script controls a X/Y-Plotter with two stepper and one servo motor.
 *  It will listen on the serial port 9600 for byte arrays which contain the following information:
 *    - moving mode (0 - MOVETO, 1 - LINETO, 2 - ORIGIN)
 *    - x-Position ( !! this will be the total of 4 bytes !! )
 *    - y-Position ( !! this will be the total of 4 bytes !! )
 *  You have to be careful not to send the command to fast, the script doesn't contain a possibility 
 *  to give feedback and it can only remember about 7 pending commands. 
 *  Everything after that will not be executed!
 */

//include Servo library and initializing servo object and global int for position
#include <Servo.h>
Servo servo;
int servoPos;

//const var for moveMode
const byte MOVETO = 0;
const byte LINETO = 1;
const byte ORIGIN = 2;

//const float for ratio different motormovement
const float MOTOR_DIFF = 1.3;

//microsteps required by driver for full step
const int MICROSTEPS = 16;

//for globally saving the position
int xPos = 0;
int yPos = 0;

//pins
int xDirPin = 4;
int xStepPin = 5;
int yDirPin = 8;
int yStepPin = 9;

int servoPin = 6;

void setup() {
  Serial.begin(9600);

  /*---------Declaring PinModes and make sure they're LOW---------*/
  // x- Motor
  pinMode(xDirPin, OUTPUT); //dirPin
  pinMode( xStepPin, OUTPUT); //stepPin
  digitalWrite(xDirPin, LOW);
  digitalWrite( xStepPin, LOW);

  // y- Motor +/- 8V, x-Motor +/- 16V
  pinMode( yDirPin, OUTPUT); //dirPin
  pinMode( yStepPin, OUTPUT); //stepPin
  digitalWrite( yDirPin, LOW);
  digitalWrite( yStepPin, LOW);

  //attach servomotor and bring it to the up position
  servo.attach(servoPin);
  penUp();

}//void-setup

void loop() {
  
  //receiving data (bytearrays) from Serial,
  if (Serial.available() >= 9) {
    byte type = Serial.read();
    byte xByte = Serial.read();
    byte xByte2 = Serial.read();
    byte xByte3 = Serial.read();
    byte xByte4 = Serial.read();
    byte yByte = Serial.read();
    byte yByte2 = Serial.read();
    byte yByte3 = Serial.read();
    byte yByte4 = Serial.read();

    //adding bytes for x and y parameter
    int x = (int) xByte + (int) xByte2 + (int) xByte3  + (int) xByte4;
    int y = (int) yByte + (int) yByte2 + (int) yByte3  + (int) yByte4;

    //compensating the different motors and gearwheels
    y *= MOTOR_DIFF;
    //motor driver requires 16 microsteps per full stepp
    y *= MICROSTEPS;
    x *= MICROSTEPS;

    //different movetypes
    if (type == MOVETO) {
      moveToPoint(x, y);
    } else if (type == LINETO) {
      lineToPoint(x, y);
    } else if (type == ORIGIN) {
      moveToOrigin();
    }

  }//Serial.available()

}//void-loop

//puts Pen down and moves to position
void lineToPoint(int x, int y) {
  penDown();
  headToPoint(x, y);
}//void-lineToPoint()

//puts Pen up and moves to position
void moveToPoint(int x, int y) {
  penUp();
  headToPoint(x, y);
}//void-moveToPoint

//moves to Position
void headToPoint(int x, int y) {
  //calculating difference to the current position
  float xDiff = (float) (xPos - x);
  float yDiff = (float) (yPos - y);

  //ratio from x to y
  float r = abs(xDiff) / abs(yDiff);

  //check if line is flat
  bool flat = (r > 1) ? true : false;

  //setting direction and positiv value if difference < 0
  bool xDir;
  bool yDir;

  if (xDiff < 0) {
    xDir = true;
    xDiff *= (-1);
  } else {
    xDir = false;
  }

  if (yDiff < 0) {
    yDir = true;
    yDiff *= (-1);
  } else {
    yDir = false;
  }

  //checking if line is flat, if true the ratio has to be inverted
  if (flat) {
    r = 1 / r;
    float count = 0;

    //moving stepper and updating difference variable
    while (xDiff > 0 && yDiff > 0) {
      if (xDiff > 0 ) {
        moveStepper(1, xDir, true);
        xDiff--;
      }
      count = count + r;
      if (count >= 1 && yDiff > 0) {
        moveStepper(1, yDir, false);
        count--;
        yDiff--;
      }
      delayMicroseconds(600);
    }//while

  } else {
    float count = 0;

    while (xDiff > 0 && yDiff > 0) {
      if (yDiff > 0) {
        moveStepper(1, yDir, false);
        yDiff--;
      }
      count = count + r;
      if (count >= 1 && xDiff > 0) {
        moveStepper(1, xDir, true);
        count--;
        xDiff--;
      }
      delayMicroseconds(600);
    }//while

  }

}//void-headToPoint()

//pen up and moves both motors to the origin point
void moveToOrigin() {
  penUp();
  headToPoint(0, 0);

}//void-moveToOrigin

//moves Stepper relativly to the current position
//int steps -> number of steps
//bool right -> true moves to the right side, false to the left
//bool x -> true operates the motor on the x-axis, false the y-axis
void moveStepper(int steps, bool right, bool x) {

  //depending which motor should be moved
  int stepPin = (x) ?  xStepPin :  yStepPin;
  int dirPin = (x) ? xDirPin :  yDirPin;

  // setting direction
  digitalWrite(dirPin, (right) ? HIGH : LOW);

  digitalWrite(stepPin, HIGH);
  delayMicroseconds(20);
  digitalWrite(stepPin, LOW);

  //saving new position
  if (x) {
    xPos += (right) ? steps : steps * (-1);
  } else {
    yPos += (right) ? steps : steps * (-1);
  }

  //delay(10);
}//void-moveStepper()

//moves Servomotor - pen down
void penDown() {
  servo.write(75);
  delay(30);
}//void-penDown()

//moves servo - pen up
void penUp() {
  servo.write(110);
  delay(30);
}//void-penUp()

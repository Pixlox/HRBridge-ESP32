# HRBridge-ESP32
A bridge between your Apple Watch, and any BLE supporting sport device, using an ESP32.

## How it works
Essentially, the Apple Watch application pings HR info to the iPhone application. This gets sent to the ESP32. Then, this signal is broadcast for devices (ie. cycling computers, trainers, etc), to find. 

## Why not broadcast from iPhone?
This solution is made for specific scenarios where the iPhone must _also_ be connected to the target device. I created this in particular, because my Magene C606 could not pair with my Apple Watch using HeartCast (or similar applications). It may be helpful for you too!

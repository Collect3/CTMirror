CTMirror
========
Library to mirror touches from one device to another device.


Usage
=====
Simply drop into your project and call the start method on the player or recorder

```
#if TARGET_IPHONE_SIMULATOR
    [[CTMirror sharedInstance].player start];
#else
    [[CTMirror sharedInstance].recorder start];
#endif
```

Demo
=====
Run the demo project MirrorDemo on a device and the iOS simulator. The touches will be mirrored from the device to the simulator.

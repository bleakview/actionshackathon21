//this code includes svg art from https://www.svgrepo.com/
//this code incluedes sound from https://freesound.org/
//please check https://www.ubiqueiot.com/posts/flutter-reactive-ble
//for more information in connection to ble
import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:dart_amqp/dart_amqp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:gitwatch/build_status.dart';
import 'package:location_permissions/location_permissions.dart';

void main() {
  runApp(const TrackGitActionApp());
}

class TrackGitActionApp extends StatelessWidget {
  const TrackGitActionApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Track Git Action',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TrackGitAction(title: 'Track Git Action'),
    );
  }
}

class TrackGitAction extends StatefulWidget {
  const TrackGitAction({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<TrackGitAction> createState() => _TrackGitAction();
}

class _TrackGitAction extends State<TrackGitAction> {
  bool _foundDeviceWaitingToConnect = false;
  bool _scanStarted = false;
  bool _playsound = false;
  bool _connected = false;
  String statusImage = "assets/images/empty.svg";
  String statusText = "";
  final player = AudioCache();

// Bluetooth related variables
  late DiscoveredDevice _ubiqueDevice;
  final flutterReactiveBle = FlutterReactiveBle();
  late StreamSubscription<DiscoveredDevice> _scanStream;
  late QualifiedCharacteristic _rxCharacteristic;
// These are the UUIDs of your device
  final Uuid serviceUuid = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
  final Uuid characteristicUuid =
      Uuid.parse("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
  Client client = Client(
      settings: ConnectionSettings(
    host: "{url of amqp server}",
    virtualHost: "{virtua host of server}",
    authProvider: const PlainAuthenticator("{username}", "{password}"),
  ));
  void _startScan() async {
// Platform permissions handling stuff
    bool permGranted = false;
    setState(() {
      _scanStarted = true;
    });
    PermissionStatus permission;
    if (Platform.isAndroid) {
      permission = await LocationPermissions().requestPermissions();
      if (permission == PermissionStatus.granted) permGranted = true;
    } else if (Platform.isIOS) {
      permGranted = true;
    }
// Main scanning logic happens here ⤵️
    if (permGranted) {
      _scanStream =
          flutterReactiveBle.scanForDevices(withServices: []).listen((device) {
        // Change this string to what you defined in Zephyr
        if (device.name == 'GITHUB_ACTION_IOT') {
          setState(() {
            _ubiqueDevice = device;
            _foundDeviceWaitingToConnect = true;
          });
        }
      });
    }
  }

  void _connectToDevice() {
    // We're done scanning, we can cancel it
    _scanStream.cancel();
    // Let's listen to our connection so we can make updates on a state change
    Stream<ConnectionStateUpdate> _currentConnectionStream = flutterReactiveBle
        .connectToAdvertisingDevice(
            id: _ubiqueDevice.id,
            prescanDuration: const Duration(seconds: 1),
            withServices: []);
    _currentConnectionStream.listen((event) {
      switch (event.connectionState) {
        // We're connected and good to go!
        case DeviceConnectionState.connected:
          {
            _rxCharacteristic = QualifiedCharacteristic(
                serviceId: serviceUuid,
                characteristicId: characteristicUuid,
                deviceId: event.deviceId);
            setState(() {
              _foundDeviceWaitingToConnect = false;
              _connected = true;
            });
            break;
          }
        // Can add various state state updates on disconnect
        case DeviceConnectionState.disconnected:
          {
            setState(() {
              _foundDeviceWaitingToConnect = false;
              _scanStarted = false;
              _connected = false;
            });

            break;
          }
        default:
      }
    });
  }

  Future<void> initQueue() async {
    Channel channel = await client.channel();
    Queue queue = await channel.queue("github", durable: true);
    Consumer consumer = await queue.consume();
    print(" [*] Waiting for messages. To exit, press CTRL+C");
    consumer.listen((message) {
      var receivedMessage = message.payloadAsString;
      var splittedReceivedMessage = receivedMessage.split("_");
      if (splittedReceivedMessage.length == 2) {
        if (splittedReceivedMessage[0] == "dial") {
          var statusValue = int.tryParse(splittedReceivedMessage[1]);
          if (statusValue != null) {
            setStatusImage(statusValue);
          }
        }
      }
      if (_connected) {
        flutterReactiveBle.writeCharacteristicWithResponse(_rxCharacteristic,
            value: utf8.encode(receivedMessage));
      }
      print(" [x] Received ${message.payloadAsString}");
    });
  }

  void setStatusImage(int status) {
    var currentStatusImage = "assets/images/empty.svg";
    var currentStatusText = "";

    if ((0 < status) && (status <= 36)) {
      currentStatusImage = "assets/images/search-svgrepo-com.svg";
      currentStatusText = "Getting resources ...";
      if (_playsound) {
        player.play('420763__relwin__orch-tunestartstop.mp3');
      }
    }
    if ((37 <= status) && (status <= 72)) {
      currentStatusImage = "assets/images/crane-construction-svgrepo-com.svg";
      currentStatusText = "Building ...";
      if (_playsound) {
        player.play('416414__pfranzen__construction-work.mp3');
      }
    }
    if ((73 <= status) && (status <= 108)) {
      currentStatusImage = "assets/images/cargo-ship-svgrepo-com.svg";
      currentStatusText = "Deploying ...";
      if (_playsound) {
        player.play('23722__milo__ship2-bergen.mp3');
      }
    }
    if ((109 <= status) && (status <= 144)) {
      currentStatusImage = "assets/images/team-success-svgrepo-com.svg";
      currentStatusText = "Success !!!";
      if (_playsound) {
        player.play('352041__robinhood76__06784-cartoon-admiration-wows.mp3');
      }
    }
    if ((145 <= status) && (status < 180)) {
      currentStatusImage = "assets/images/explosion-bomb-svgrepo-com.svg";
      currentStatusText = "Failed !!! :-(";
      if (_playsound) {
        player.play('186896__mrmacross__negativebuzz.mp3');
      }
    }
    setState(() {
      statusImage = currentStatusImage;
      statusText = currentStatusText;
    });
  }

  @override
  void initState() {
    super.initState();
    initQueue().then((value) => null);
  }

  @override
  void dispose() async {
    await client.close();
    super.dispose();
  }

  void _resetDial() {
    if (_connected) {
      var characterSeries = "dial_0";
      setState(() {
        statusImage = "assets/images/empty.svg";
        statusText = "";
      });
      flutterReactiveBle.writeCharacteristicWithResponse(_rxCharacteristic,
          value: utf8.encode(characterSeries));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            BuildStatus(statusImage, statusText),
          ],
        ),
      ),
      persistentFooterButtons: [
        // We want to enable this button if the scan has NOT started
        // If the scan HAS started, it should be disabled.
        _playsound
            // True condition
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue, // background
                  onPrimary: Colors.white, // foreground
                ),
                onPressed: () {
                  setState(() {
                    _playsound = false;
                  });
                },
                child: const Icon(Icons.speaker),
              )
            :
            // False condition
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Colors.grey, // background
                  onPrimary: Colors.white, // foreground
                ),
                onPressed: () {
                  setState(() {
                    _playsound = true;
                  });
                },
                child: const Icon(Icons.speaker),
              ),

        _scanStarted
            // True condition
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Colors.grey, // background
                  onPrimary: Colors.white, // foreground
                ),
                onPressed: () {},
                child: const Icon(Icons.search),
              )
            // False condition
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue, // background
                  onPrimary: Colors.white, // foreground
                ),
                onPressed: _startScan,
                child: const Icon(Icons.search),
              ),
        _foundDeviceWaitingToConnect
            // True condition
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue, // background
                  onPrimary: Colors.white, // foreground
                ),
                onPressed: _connectToDevice,
                child: const Icon(Icons.bluetooth),
              )
            // False condition
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Colors.grey, // background
                  onPrimary: Colors.white, // foreground
                ),
                onPressed: () {},
                child: const Icon(Icons.bluetooth),
              ),
        _connected
            // True condition
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue, // background
                  onPrimary: Colors.white, // foreground
                ),
                onPressed: _resetDial,
                child: const Icon(Icons.speed_rounded),
              )
            // False condition
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Colors.grey, // background
                  onPrimary: Colors.white, // foreground
                ),
                onPressed: () {},
                child: const Icon(Icons.speed_rounded),
              ),
      ],
    );
  }
}

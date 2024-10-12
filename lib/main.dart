import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LED Sender',
      home: LedControl(),
    );
  }
}

class LedControl extends StatefulWidget {
  @override
  _LedControlState createState() => _LedControlState();
}

class _LedControlState extends State<LedControl> {
  int ledAddress = 0;
  final int redValue = 255;
  final int greenValue = 0;
  final int blueValue = 0;

  void sendLedAddressAndColor() {
    String message = '$ledAddress,$redValue,$greenValue,$blueValue';
    // Hier musst du den Code hinzufügen, um die Nachricht über BLE zu senden
    print('Sent: $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('LED Sender')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('LED Address: $ledAddress'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      ledAddress++;
                      if (ledAddress > 59) ledAddress = 1;
                    });
                    sendLedAddressAndColor();
                  },
                  child: Text('Increase LED'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      ledAddress--;
                      if (ledAddress < 1) ledAddress = 59;
                    });
                    sendLedAddressAndColor();
                  },
                  child: Text('Decrease LED'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

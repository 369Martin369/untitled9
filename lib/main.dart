import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

// Define UUIDs for the BLE Service and Characteristic
final String serviceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
final String characteristicUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

// Die BLE-Adresse des Empfängers
final String receiverAddress = "34:85:18:71:4C:AD";

// BLE-Dienst und Charakteristik, die nach der Verbindung benutzt werden
BluetoothCharacteristic? targetCharacteristic;

void connectToBLEDevice(Function onCharacteristicFound) async {
  FlutterBlue flutterBlue = FlutterBlue.instance;

  // Scanne nach verfügbaren BLE-Geräten
  flutterBlue.startScan(timeout: Duration(seconds: 5));

  // Nach Geräten suchen und auf das richtige Gerät mit der richtigen Adresse warten
  var subscription = flutterBlue.scanResults.listen((results) {
    for (ScanResult result in results) {
      if (result.device.id.id == receiverAddress) {
        // Gerät gefunden, Verbindung herstellen
        flutterBlue.stopScan();
        print("Connecting to Server: ${result.device.name}");
        result.device.connect().then((_) async {
          // Nach den Services des Geräts suchen
          List<BluetoothService> services = await result.device.discoverServices();
          for (BluetoothService service in services) {
            if (service.uuid.toString() == serviceUUID) {
              // Service gefunden, nun die Charakteristik holen
              for (BluetoothCharacteristic characteristic in service.characteristics) {
                if (characteristic.uuid.toString() == characteristicUUID) {
                  targetCharacteristic = characteristic;
                  print("Connected to the characteristic");
                  onCharacteristicFound();
                  break;
                }
              }
            }
          }
        });
        break;
      }
    }
  });

  // Die Suche nach Geräten nach 5 Sekunden stoppen
  Future.delayed(Duration(seconds: 5), () {
    subscription.cancel();
    flutterBlue.stopScan();
  });
}

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
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    connectToBLEDevice(() {
      setState(() {
        isConnected = true;
      });
    });
  }

  void sendLedAddressAndColor() {
    if (targetCharacteristic != null) {
      String message = '$ledAddress,$redValue,$greenValue,$blueValue';
      List<int> bytes = message.codeUnits;
      targetCharacteristic!.write(bytes); // Nachricht über BLE senden
      print('Sent: $message');
    } else {
      print('No connected BLE characteristic to send data');
    }
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
            Text(isConnected ? 'Connected to BLE' : 'Not connected to BLE'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: isConnected
                      ? () {
                    setState(() {
                      ledAddress++;
                      if (ledAddress > 59) ledAddress = 1;
                    });
                    sendLedAddressAndColor();
                  }
                      : null,
                  child: Text('Increase LED'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: isConnected
                      ? () {
                    setState(() {
                      ledAddress--;
                      if (ledAddress < 1) ledAddress = 59;
                    });
                    sendLedAddressAndColor();
                  }
                      : null,
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

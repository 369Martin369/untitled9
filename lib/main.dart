import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PartsScreen(),
    );
  }
}

class PartsScreen extends StatefulWidget {
  @override
  _PartsScreenState createState() => _PartsScreenState();
}

class _PartsScreenState extends State<PartsScreen> {
  List<List<String>> parts = [];
  List<List<String>> filteredParts = [];
  List<String> columnNames = [];
  ScrollController _verticalScrollController = ScrollController();
  ScrollController _horizontalScrollController = ScrollController();
  TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;

  // Bluetooth
  final String serviceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String characteristicUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  final String receiverAddress = "34:85:18:71:4C:AD";
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? targetCharacteristic;

  @override
  void initState() {
    super.initState();
    fetchParts();
    _searchController.addListener(() {
      filterParts(_searchController.text);
    });
  }

  Future<void> fetchParts() async {
    final response = await http.get(Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/1-eBpGAi2vq9oCVu7BEPgbs_sGOi86geyoc6D-sb01I8/values/Data?key=AIzaSyDZ5i4cSIVxrNb_h2-olHAZBIv6hGqNxRM'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        parts = List<List<String>>.from(data['values'].map((item) => List<String>.from(item)));
        columnNames = List<String>.from(parts.isNotEmpty ? parts[0] : []);
        filteredParts = List.from(parts.sublist(1));
      });
    } else {
      throw Exception('Failed to load data');
    }
  }

  void filterParts(String query) {
    setState(() {
      filteredParts = parts
          .sublist(1)
          .where((part) => part.any((field) => field.toLowerCase().contains(query.toLowerCase())))
          .toList();
    });
  }

  void toggleSearchVisibility() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        filterParts('');
      }
    });
  }

  // Funktion, um die Verbindung zu einem BLE-Gerät herzustellen
  Future<void> connectToBLEDevice() async {
    FlutterBlue flutterBlue = FlutterBlue.instance;
    flutterBlue.startScan(timeout: Duration(seconds: 5));

    var subscription = flutterBlue.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (result.device.id.id == receiverAddress) {
          flutterBlue.stopScan();
          connectedDevice = result.device;
          print("Connected to Server: ${result.device.name}");
          connectedDevice?.connect().then((_) {
            discoverServices();
          });
          break;
        }
      }
    });

    Future.delayed(Duration(seconds: 5), () {
      subscription.cancel();
      flutterBlue.stopScan();
    });
  }

  // Entdecke die Dienste und Charakteristika des Geräts
  Future<void> discoverServices() async {
    if (connectedDevice != null) {
      List<BluetoothService> services = await connectedDevice!.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == serviceUUID) {
          targetCharacteristic = service.characteristics.firstWhere(
                (c) => c.uuid.toString() == characteristicUUID,
            orElse: () => service.characteristics.first,
          );
          break;
        }
      }
    }
  }

  void sendLedAddressAndColor(int ledAddress, int redValue, int greenValue, int blueValue) {
    if (targetCharacteristic != null) {
      String message = '$ledAddress,$redValue,$greenValue,$blueValue';
      targetCharacteristic!.write(utf8.encode(message));
      print('Sent: $message');
    } else {
      print('No connected BLE characteristic to send data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            SizedBox(height: 12), // Weniger Höhe für den ersten Abstand
            Text(
              'Parts Inventory',
              style: TextStyle(fontSize: 24), // Textgröße anpassen
            ),
            Container(
              color: Colors.red, // Hintergrundfarbe auf Rot setzen
              padding: EdgeInsets.symmetric(vertical: 0.0), // Padding für die Symbolleiste anpassen
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.add, size: 30), // Symbolgröße anpassen
                    onPressed: () {},
                    tooltip: 'Add Part',
                  ),
                  SizedBox(width: 20), // Abstand zwischen den Symbolen
                  IconButton(
                    icon: Icon(Icons.search, size: 30), // Symbolgröße anpassen
                    onPressed: toggleSearchVisibility,
                    tooltip: 'Search Part',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 20), // Abstand unter dem AppBar
          if (_isSearchVisible)
            Padding(
              padding: const EdgeInsets.all(5.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
          Expanded(
            child: filteredParts.isEmpty
                ? Center(child: CircularProgressIndicator())
                : Scrollbar(
              controller: _verticalScrollController,
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: columnNames.map((col) {
                      return DataColumn(
                        label: Text(col),
                      );
                    }).toList(),
                    rows: filteredParts.map((part) {
                      return DataRow(cells: [
                        for (int i = 0; i < part.length; i++) DataCell(
                          GestureDetector(
                            onTap: () {
                              int ledAddress = int.tryParse(part[0]) ?? 0; // Beispiel: Erste Spalte als Adresse
                              int redValue = int.tryParse(part[1]) ?? 0;   // Beispiel: Zweite Spalte als Rotwert
                              int greenValue = int.tryParse(part[2]) ?? 0; // Beispiel: Dritte Spalte als Grünwert
                              int blueValue = int.tryParse(part[3]) ?? 0;  // Beispiel: Vierte Spalte als Blauwert
                              sendLedAddressAndColor(ledAddress, redValue, greenValue, blueValue);
                            },
                            child: Text(part[i]),
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

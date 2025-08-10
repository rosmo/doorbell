import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:wifi_scan_windows/available_network.dart';
import 'package:wifi_scan_windows/wifi_scan_windows.dart';
import 'package:flutter_onscreen_keyboard/flutter_onscreen_keyboard.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'dart:io';

Future<Map<String, String?>> getNetworkInfo() async {
  final NetworkInfo networkInfo = NetworkInfo();
  String? wifiName, wifiIPv4, wifiIPv6, wifiGatewayIP, wifiSubmask;

  try {
    wifiName = await networkInfo.getWifiName();
  } on Exception catch (e) {
    developer.log('Failed to get Wifi Name', error: e);
  }

  try {
    wifiIPv4 = await networkInfo.getWifiIP();
  } on Exception catch (e) {
    developer.log('Failed to get Wifi IPv4', error: e);
  }

  try {
    wifiIPv6 = await networkInfo.getWifiIPv6();
  } on Exception catch (e) {
    developer.log('Failed to get Wifi IPv6', error: e);
  }

  try {
    wifiSubmask = await networkInfo.getWifiSubmask();
  } on Exception catch (e) {
    developer.log('Failed to get Wifi submask address', error: e);
  }

  try {
    wifiGatewayIP = await networkInfo.getWifiGatewayIP();
  } on Exception catch (e) {
    developer.log('Failed to get Wifi gateway address', error: e);
  }

  return {
    'name': wifiName,
    'ipv4': wifiIPv4,
    'ipv6': wifiIPv6,
    'gw': wifiGatewayIP,
    'netmask': wifiSubmask,
  };
}

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => SettingsState();
}

class SettingsState extends State<Settings> {
  List<String> networks = [];
  String currentNetwork = '';
  SharedPreferences? prefs;
  final homeAssistantUrlController = TextEditingController();
  final homeAssistantApiUrlController = TextEditingController();
  final homeAssistantTokenController = TextEditingController();
  final wifiPasswordController = TextEditingController();
  final musicDirectoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    populateNetworks();
    setCurrentNetwork();
    populateHomeAssistantUrl();
    populateHomeAssistantApiUrl();
    populateHomeAssistantToken();
    populateWifiPassword();
    populateMusicDirectory();

    homeAssistantUrlController.addListener(() async {
      prefs = await SharedPreferences.getInstance();
      final text = homeAssistantUrlController.text;
      prefs!.setString('homeAssistantUrl', text);
    });
    homeAssistantApiUrlController.addListener(() async {
      prefs = await SharedPreferences.getInstance();
      final text = homeAssistantApiUrlController.text;
      prefs!.setString('homeAssistantApiUrl', text);
    });
    homeAssistantTokenController.addListener(() async {
      prefs = await SharedPreferences.getInstance();
      final text = homeAssistantTokenController.text;
      prefs!.setString('homeAssistantToken', text);
    });
    wifiPasswordController.addListener(() async {
      prefs = await SharedPreferences.getInstance();
      final text = wifiPasswordController.text;
      prefs!.setString('wifiPassword', text);
    });
    musicDirectoryController.addListener(() async {
      prefs = await SharedPreferences.getInstance();
      final text = musicDirectoryController.text;
      prefs!.setString('musicDirectory', text);
    });
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is removed from the widget tree.
    // This also removes the _printLatestValue listener.
    homeAssistantUrlController.dispose();
    homeAssistantApiUrlController.dispose();
    homeAssistantTokenController.dispose();
    wifiPasswordController.dispose();
    musicDirectoryController.dispose();

    super.dispose();
  }

  Future<void> populateHomeAssistantUrl() async {
    prefs = await SharedPreferences.getInstance();
    var url = prefs!.getString('homeAssistantUrl');
    setState(() {
      homeAssistantUrlController.value = TextEditingValue(text: url ?? '');
    });
  }

  Future<void> populateHomeAssistantApiUrl() async {
    prefs = await SharedPreferences.getInstance();
    var url = prefs!.getString('homeAssistantApiUrl');
    setState(() {
      homeAssistantApiUrlController.value = TextEditingValue(text: url ?? '');
    });
  }

  Future<void> populateHomeAssistantToken() async {
    prefs = await SharedPreferences.getInstance();
    var url = prefs!.getString('homeAssistantToken');
    setState(() {
      homeAssistantTokenController.value = TextEditingValue(text: url ?? '');
    });
  }

  Future<void> populateWifiPassword() async {
    prefs = await SharedPreferences.getInstance();
    var url = prefs!.getString('wifiPassword');
    setState(() {
      wifiPasswordController.value = TextEditingValue(text: url ?? '');
    });
  }

  Future<void> populateMusicDirectory() async {
    prefs = await SharedPreferences.getInstance();
    var url = prefs!.getString('musicDirectory');
    setState(() {
      musicDirectoryController.value = TextEditingValue(text: url ?? '');
    });
  }

  Future<void> setCurrentNetwork() async {
    var result = await getNetworkInfo();
    setState(() {
      currentNetwork = result['name'] ?? '';
    });
  }

  Future<void> populateNetworks() async {
    var result = await scanWifiAccessPoints();
    setState(() {
      networks = result;
    });
  }

  Future<List<String>> scanWifiAccessPoints() async {
    List<String> foundNetworks = [];

    if (Platform.isWindows) {
      final WifiScanWindows wifiScanWindowsPlugin = WifiScanWindows();
      List<AvailableNetwork>? result = await wifiScanWindowsPlugin
          .getAvailableNetworks();
      for (var network in result ?? []) {
        foundNetworks.add(network.ssid);
      }
    }
    return foundNetworks.where((n) => n != '').toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.all(20.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            spacing: 16.0,
            children: [
              Text(
                'Network connection',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0),
              ),
              ElevatedButton(
                onPressed: () async {
                  List<String> foundNetworks = await scanWifiAccessPoints();
                  setState(() {
                    networks = foundNetworks;
                  });
                },
                child: const Text('Scan for networks'),
              ),
              DropdownButton<String>(
                value: currentNetwork,
                items: networks.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    currentNetwork = newValue!;
                  });
                },
                hint: Text(
                  'Select a WiFI network to connect to',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OnscreenKeyboardTextField(
                controller: wifiPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Wifi password',
                ),
              ),
              ElevatedButton(
                onPressed: () async {},
                child: const Text('Connect to network'),
              ),
              Text(
                'Music control settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0),
              ),
              OnscreenKeyboardTextField(
                controller: musicDirectoryController,
                obscureText: false,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Music directory',
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  String? path = await FilesystemPicker.open(
                    title: 'Select music folder',
                    context: context,
                    rootDirectory: Platform.isLinux
                        ? Directory('/')
                        : Directory('C:\\'),
                    fsType: FilesystemType.folder,
                    pickText: 'Use this folder for music',
                  );
                  setState(() {
                    musicDirectoryController.value = TextEditingValue(
                      text: path ?? '',
                    );
                  });
                },
                child: const Text('Pick directory'),
              ),
              Text('Place M3U playlists in a subdirectory called "Playlists".'),
              Text(
                'Home control settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0),
              ),
              OnscreenKeyboardTextField(
                controller: homeAssistantUrlController,
                obscureText: false,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Home control URL',
                ),
              ),
              Text(
                'Home Assistant settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0),
              ),
              OnscreenKeyboardTextField(
                controller: homeAssistantApiUrlController,
                obscureText: false,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Home Assistant API URL',
                ),
              ),
              OnscreenKeyboardTextField(
                controller: homeAssistantTokenController,
                obscureText: false,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Home Assistant token',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

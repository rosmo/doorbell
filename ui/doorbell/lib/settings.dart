import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:wifi_scan_windows/available_network.dart';
import 'package:wifi_scan_windows/wifi_scan_windows.dart';
import 'package:flutter_onscreen_keyboard/flutter_onscreen_keyboard.dart';

import 'dart:developer' as developer;
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    populateNetworks();
    setCurrentNetwork();
    populateHomeAssistantUrl();

    homeAssistantUrlController.addListener(() async {
      prefs = await SharedPreferences.getInstance();
      final text = homeAssistantUrlController.text;
      prefs!.setString('homeAssistantUrl', text);
    });
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is removed from the widget tree.
    // This also removes the _printLatestValue listener.
    homeAssistantUrlController.dispose();
    super.dispose();
  }

  Future<void> populateHomeAssistantUrl() async {
    prefs = await SharedPreferences.getInstance();
    var url = prefs!.getString('homeAssistantUrl');
    setState(() {
      homeAssistantUrlController.value = TextEditingValue(text: url ?? '');
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
        child: Column(
          spacing: 16.0,
          children: [
            Text(
              'Home Assistant settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0),
            ),
            OnscreenKeyboardTextField(
              controller: homeAssistantUrlController,
              obscureText: false,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Home Assistant URL',
              ),
            ),
            Text(
              'Network connection',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0),
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
            ElevatedButton(
              onPressed: () async {
                List<String> foundNetworks = await scanWifiAccessPoints();
                setState(() {
                  networks = foundNetworks;
                });
              },
              child: const Text('Scan for networks'),
            ),
          ],
        ),
      ),
    );
  }
}

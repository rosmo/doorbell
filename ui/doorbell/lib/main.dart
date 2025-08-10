import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:one_clock/one_clock.dart';
import 'package:flutter_onscreen_keyboard/flutter_onscreen_keyboard.dart';
import 'media_kit_stub.dart' if (dart.library.io) 'media_kit_impl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_linux_webview/flutter_linux_webview.dart';

import 'dart:io';
import 'settings.dart';
import 'homecontrol.dart';
import 'doorbell.dart';
import 'music.dart';

void _enablePlatformOverrideForDesktop() {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }
}

void main() {
  _enablePlatformOverrideForDesktop();
  WidgetsFlutterBinding.ensureInitialized();
  initMediaKit(); // Initialise just_audio_media_kit for Linux/Windows.

  if (Platform.isLinux) {
    LinuxWebViewPlugin.initialize(
      options: <String, String?>{
        'user-agent': 'Doorbell',
        'remote-debugging-port': '8888',
        'autoplay-policy': 'no-user-gesture-required',
      },
    );

    WebView.platform = LinuxWebView();
  }
  runApp(const MainApp());
}

class AppState extends ChangeNotifier {
  var ringing = false;
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MaterialApp(
        builder: OnscreenKeyboard.builder(
          aspectRatio: 1.5, //16.0 / 9.0,
          layout: const MobileKeyboardLayout(),
          width: (context) => MediaQuery.sizeOf(context).width / 1.8,
          showControlBar: true,
        ),
        title: 'Doorbell',
        theme: ThemeData(
          fontFamily: 'Raleway',
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.lightGreen,
            brightness: Brightness.dark,
          ),
        ),
        home: HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int currentPageIndex = 0;
  String _connectionStatus = 'Unknown';
  DateTime dateTime = DateTime.now();
  final pageController = PageController(initialPage: 0, keepPage: true);
  ShapeBorder indicatorShape = RoundedRectangleBorder();
  final double navIconSize = 48.0;

  @override
  void initState() {
    super.initState();

    _initNetworkInfo();
  }

  Future<void> _initNetworkInfo() async {
    Map<String, String?> conn = await getNetworkInfo();
    setState(() {
      if (conn['name'] != null) {
        _connectionStatus = conn['name']!;
      } else {
        _connectionStatus = 'No WiFi';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(32.0),
      child: Scaffold(
        body: Row(
          children: <Widget>[
            NavigationRail(
              minWidth: 200.0,
              backgroundColor: Colors.green.shade900,
              selectedIndex: currentPageIndex,
              groupAlignment: -1.0,
              onDestinationSelected: (int index) {
                setState(() {
                  currentPageIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              leading: Card(
                color: Colors.green.shade800,
                margin: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.wifi),
                      label: Text(_connectionStatus),
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          width: 3.0,
                          color: Colors.lightGreenAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DigitalClock(
                      format: 'MMMM d, y\nHH:mm:ss',
                      datetime: dateTime,
                      textScaleFactor: 1,
                      showSeconds: false,
                      isLive: true,
                      digitalClockTextColor: Colors.lightGreenAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 80,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        //color: Colors.black,
                        //shape: BoxShape.rectangle,
                        //borderRadius: BorderRadius.all(Radius.zero),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              destinations: <NavigationRailDestination>[
                NavigationRailDestination(
                  padding: const EdgeInsets.all(12.0),
                  icon: Icon(Icons.doorbell_outlined, size: navIconSize),
                  selectedIcon: Icon(Icons.doorbell, size: navIconSize),
                  label: Text('Doorbell'),
                  indicatorShape: indicatorShape,
                ),
                NavigationRailDestination(
                  padding: const EdgeInsets.all(12.0),
                  icon: Icon(Icons.light_outlined, size: navIconSize),
                  selectedIcon: Icon(Icons.light, size: navIconSize),
                  label: Text('Home control'),
                  indicatorShape: indicatorShape,
                ),
                NavigationRailDestination(
                  padding: const EdgeInsets.all(12.0),
                  icon: Icon(Icons.music_note_outlined, size: navIconSize),
                  selectedIcon: Icon(Icons.music_note, size: navIconSize),
                  label: Text('Music'),
                  indicatorShape: indicatorShape,
                ),
                NavigationRailDestination(
                  padding: const EdgeInsets.all(12.0),
                  icon: Icon(Icons.settings_outlined, size: navIconSize),
                  selectedIcon: Icon(Icons.settings, size: navIconSize),
                  label: Text('Settings'),
                  indicatorShape: indicatorShape,
                ),
              ],
            ),
            const VerticalDivider(thickness: 2, width: 2),
            // This is the main content.
            Expanded(
              child: <Widget>[
                DoorBell(),
                HomeControl(),
                Music(),
                Settings(),
              ][currentPageIndex],
            ),
          ],
        ),
      ),
    );
  }
}

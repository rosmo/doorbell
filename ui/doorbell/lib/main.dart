import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:one_clock/one_clock.dart';
import 'package:flutter_onscreen_keyboard/flutter_onscreen_keyboard.dart';

import 'dart:io';
import 'settings.dart';
import 'homecontrol.dart';

void _enablePlatformOverrideForDesktop() {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }
}

void main() {
  _enablePlatformOverrideForDesktop();
  WidgetsFlutterBinding.ensureInitialized();
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
          aspectRatio: 16.0 / 9.0,
          layout: const MobileKeyboardLayout(),
          width: (context) => MediaQuery.sizeOf(context).width / 2,
          // ...more options
        ),
        title: 'Doorbell',
        theme: ThemeData(
          fontFamily: 'Raleway',
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepOrange,
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
    return Scaffold(
      appBar: AppBar(
        title: DigitalClock(
          format: 'MMMM d, y H:m:s',
          datetime: dateTime,
          textScaleFactor: 1,
          showSeconds: false,
          isLive: true,
          digitalClockTextColor: Colors.amber,
          padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 10),
          decoration: const BoxDecoration(
            //color: Colors.black,
            //shape: BoxShape.rectangle,
            //borderRadius: BorderRadius.all(Radius.zero),
          ),
        ),
        actions: <Widget>[
          OutlinedButton.icon(
            icon: const Icon(Icons.wifi),
            label: Text(_connectionStatus),
            onPressed: () {},
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        indicatorColor: Colors.amber,
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.doorbell),
            icon: Icon(Icons.doorbell_outlined),
            label: 'Doorbell',
          ),
          NavigationDestination(
            //icon: Badge(child: Icon(Icons.light)),
            icon: Icon(Icons.light),
            label: 'Home control',
          ),
          NavigationDestination(
            icon: Icon(Icons.music_note_outlined),
            label: 'Music',
          ),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      body: <Widget>[
        DoorBell(),
        HomeControl(),
        Music(),
        Settings(),
      ][currentPageIndex],
    );
  }
}

class DoorBell extends StatefulWidget {
  const DoorBell({super.key});

  @override
  State<DoorBell> createState() => DoorBellState();
}

class DoorBellState extends State<DoorBell> {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.all(8.0),
      child: SizedBox.expand(
        child: Center(
          child: Text('Doorbell', style: theme.textTheme.titleLarge),
        ),
      ),
    );
  }
}

class Music extends StatefulWidget {
  const Music({super.key});

  @override
  State<Music> createState() => MusicState();
}

class MusicState extends State<Music> {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.all(8.0),
      child: SizedBox.expand(
        child: Center(child: Text('Music', style: theme.textTheme.titleLarge)),
      ),
    );
  }
}

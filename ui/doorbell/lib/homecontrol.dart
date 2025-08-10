import 'package:flutter/material.dart';

import 'dart:io';
import 'homecontrol_windows.dart';
import 'homecontrol_linux.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeControl extends StatefulWidget {
  const HomeControl({super.key});

  @override
  State<HomeControl> createState() => HomeControlState();
}

class HomeControlState extends State<HomeControl> {
  HomeControlWindows? webviewWindows;
  HomeControlLinux? webviewLinux;

  Future<String> updateUrlToLoad() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var url = prefs.getString('homeAssistantUrl');
    return url ?? 'about:blank';
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.all(8.0),
      child: FocusDetector(
        onFocusGained: () {},
        child: SizedBox.expand(
          child: FutureBuilder<String>(
            future: updateUrlToLoad(),
            builder: (BuildContext context, AsyncSnapshot<String> url) {
              if (url.hasData) {
                if (Platform.isWindows) {
                  webviewWindows = HomeControlWindows(
                    url: url.data ?? 'about:blank',
                  );
                }
                if (Platform.isLinux) {
                  webviewLinux = HomeControlLinux(
                    url: url.data ?? 'about:blank',
                  );
                }
                return Center(
                  child: Platform.isWindows ? webviewWindows : webviewLinux,
                );
              }
              return Text('Loading...');
            },
          ),
        ),
      ),
    );
  }
}

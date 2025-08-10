import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_linux_webview/flutter_linux_webview.dart';

class HomeControlLinux extends StatefulWidget {
  final HomeControlLinuxState hcs = HomeControlLinuxState();
  final String url;

  HomeControlLinux({super.key, required this.url});

  @override
  State<HomeControlLinux> createState() => hcs;

  void loadUrl(String newUrl) {
    hcs.loadUrl(newUrl);
  }
}

class HomeControlLinuxState extends State<HomeControlLinux>
    with WidgetsBindingObserver {
  final Completer<WebViewController> _controller =
      Completer<WebViewController>();
  String url = '';

  void loadUrl(String newUrl) {}

  /// Prior to Flutter 3.10, comment out the following code since
  /// [WidgetsBindingObserver.didRequestAppExit] does not exist.
  // ===== begin: For Flutter 3.10 or later =====
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    url = widget.url;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await LinuxWebViewPlugin.terminate();
    return AppExitResponse.exit;
  }
  // ===== end: For Flutter 3.10 or later =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_linux_webview example')),
      body: WebView(
        initialUrl: url,
        initialCookies: const [],
        onWebViewCreated: (WebViewController webViewController) {
          _controller.complete(webViewController);
        },
        javascriptMode: JavascriptMode.unrestricted,
      ),
    );
  }
}

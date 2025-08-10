import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeControlWindows extends StatefulWidget {
  final HomeControlWindowsState hcs = HomeControlWindowsState();
  final String url;

  HomeControlWindows({super.key, required this.url});

  @override
  State<HomeControlWindows> createState() => hcs;

  void loadUrl(String newUrl) {
    hcs.loadUrl(newUrl);
  }
}

class HomeControlWindowsState extends State<HomeControlWindows> {
  final GlobalKey webViewKey = GlobalKey();

  String url = '';
  String title = '';
  double progress = 0;
  bool? isSecure;
  InAppWebViewController? webViewController;

  @override
  void initState() {
    super.initState();
    url = widget.url;
  }

  void loadUrl(String newUrl) {
    developer.log('Loading new URL: $newUrl');
    webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(newUrl)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          InAppWebView(
            key: webViewKey,
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              textZoom: 200,
              transparentBackground: true,
              safeBrowsingEnabled: true,
              isFraudulentWebsiteWarningEnabled: true,
            ),
            onWebViewCreated: (controller) async {
              webViewController = controller;
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
                await controller.startSafeBrowsing();
              }
            },
            onLoadStart: (controller, url) {
              if (url != null) {
                setState(() {
                  this.url = url.toString();
                  isSecure = urlIsSecure(url);
                });
              }
            },
            onLoadStop: (controller, url) async {
              if (url != null) {
                setState(() {
                  this.url = url.toString();
                });
              }

              final sslCertificate = await controller.getCertificate();
              setState(() {
                isSecure =
                    sslCertificate != null || (url != null && urlIsSecure(url));
              });
            },
            onUpdateVisitedHistory: (controller, url, isReload) {
              if (url != null) {
                setState(() {
                  this.url = url.toString();
                });
              }
            },
            onTitleChanged: (controller, title) {
              if (title != null) {
                setState(() {
                  this.title = title;
                });
              }
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                this.progress = progress / 100;
              });
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url;
              if (navigationAction.isForMainFrame &&
                  url != null &&
                  ![
                    'http',
                    'https',
                    'file',
                    'chrome',
                    'data',
                    'javascript',
                    'about',
                  ].contains(url.scheme)) {
                if (await canLaunchUrl(url)) {
                  launchUrl(url);
                  return NavigationActionPolicy.CANCEL;
                }
              }
              return NavigationActionPolicy.ALLOW;
            },
          ),
          /*  progress < 1.0
              ? LinearProgressIndicator(value: progress)
              : Container(), */
        ],
      ),
    );
  }

  static bool urlIsSecure(Uri url) {
    return (url.scheme == "https") || isLocalizedContent(url);
  }

  static bool isLocalizedContent(Uri url) {
    return (url.scheme == "file" ||
        url.scheme == "chrome" ||
        url.scheme == "data" ||
        url.scheme == "javascript" ||
        url.scheme == "about");
  }
}

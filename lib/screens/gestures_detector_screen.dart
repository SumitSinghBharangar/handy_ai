import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class GestureScreen extends StatefulWidget {
  const GestureScreen({super.key});

  @override
  State<GestureScreen> createState() => _GestureScreenState();
}

class _GestureScreenState extends State<GestureScreen> {
  String htmlData = "";

  @override
  void initState() {
    super.initState();
    loadHtml();
  }

  Future<void> loadHtml() async {
    htmlData = await rootBundle.loadString("assets/hand_tracking.html");

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (htmlData.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: InAppWebView(
          initialData: InAppWebViewInitialData(data: htmlData),
        ),
      ),
    );
  }
}

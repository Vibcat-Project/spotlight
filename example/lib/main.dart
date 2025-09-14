import 'package:flutter/material.dart';
import 'dart:async';

import 'package:spotlight/spotlight.dart';
import 'package:spotlight/spotlight_platform_interface.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  Spotlight.setOnCallHandler((type, input, updater) async {
    switch (type) {
      case CallHandlerType.onTranslate:
        // 模拟翻译
        for (var i = 0; i < 100; i++) {
          await Future.delayed(const Duration(milliseconds: 10));
          updater.update(i.toString());
        }
        break;
      case CallHandlerType.onSearch:
        break;
    }

    updater.finished();
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _spotlightPlugin = Spotlight();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Center(
          child: Column(
            children: [
              Text("按 Option + Space 呼出 Spotlight"),
              FilledButton(
                onPressed: () {
                  _spotlightPlugin.show();
                },
                child: Text('show'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

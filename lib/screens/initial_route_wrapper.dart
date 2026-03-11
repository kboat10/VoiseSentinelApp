import 'dart:io';

import 'package:flutter/material.dart';

import '../app/record_call_trigger.dart';
import '../onnx/onnx_inference_service.dart';
import 'main_shell.dart';
import 'welcome_screen.dart';

/// Decides initial screen: if opened from "record call" notification, go to MainShell.
class InitialRouteWrapper extends StatefulWidget {
  const InitialRouteWrapper({super.key});

  @override
  State<InitialRouteWrapper> createState() => _InitialRouteWrapperState();
}

class _InitialRouteWrapperState extends State<InitialRouteWrapper> {
  Widget? _initialChild;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkIntent();
  }

  Future<void> _checkIntent() async {
    if (!Platform.isAndroid) {
      if (mounted) setState(() {
        _initialChild = const WelcomeScreen();
        _checked = true;
      });
      return;
    }
    try {
      final recordCall = await OnnxInferenceService.getAndClearRecordCallIntent();
      if (recordCall) RecordCallTrigger.triggered = true;
      if (mounted) {
        setState(() {
          _initialChild = recordCall ? const MainShell() : const WelcomeScreen();
          _checked = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _initialChild = const WelcomeScreen();
        _checked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || _initialChild == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _initialChild!;
  }
}

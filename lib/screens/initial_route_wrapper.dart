import 'dart:io';

import 'package:flutter/material.dart';

import '../app/record_call_trigger.dart';
import '../services/auth_storage.dart';
import '../services/wav2vec_model_manager.dart';
import '../onnx/onnx_inference_service.dart';
import 'main_shell.dart';
import 'login_screen.dart';

/// Decides initial screen: auth gate → record call intent or welcome.
/// When logged in on Android, also kicks off Wav2Vec2 model download in background.
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
    await AuthStorage.load();
    if (!AuthStorage.isLoggedIn) {
      if (mounted) {
        setState(() {
          _initialChild = const LoginScreen();
          _checked = true;
        });
      }
      return;
    }

    // Kick off model download in background (non-blocking) whenever logged in on Android.
    if (Platform.isAndroid) {
      Wav2Vec2ModelManager.instance.ensureModel();
    }

    if (!Platform.isAndroid) {
      if (mounted) {
        setState(() {
          _initialChild = const MainShell();
          _checked = true;
        });
      }
      return;
    }
    try {
      final recordCall = await OnnxInferenceService.getAndClearRecordCallIntent();
      if (recordCall) {
        RecordCallTrigger.triggered = true;
      }
      if (mounted) {
        setState(() {
          _initialChild = const MainShell();
          _checked = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _initialChild = const MainShell();
          _checked = true;
        });
      }
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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated speech-wave style bars shown during recording.
class SpeechWaveform extends StatefulWidget {
  const SpeechWaveform({
    super.key,
    this.height = 64,
    this.barCount = 24,
    this.barWidth = 4,
    this.barSpacing = 3,
    this.color,
  });

  final double height;
  final int barCount;
  final double barWidth;
  final double barSpacing;
  final Color? color;

  @override
  State<SpeechWaveform> createState() => _SpeechWaveformState();
}

class _SpeechWaveformState extends State<SpeechWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppTheme.primaryBlue;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (i) {
              final phase = (i / widget.barCount) * math.pi * 2;
              final wave = math.sin(phase + _controller.value * math.pi * 2) * 0.5 + 0.5;
              final height = 8 + (wave * (widget.height - 16));
              return Container(
                margin: EdgeInsets.only(
                  right: i < widget.barCount - 1 ? widget.barSpacing : 0,
                ),
                width: widget.barWidth,
                height: height.clamp(8.0, widget.height - 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(widget.barWidth / 2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

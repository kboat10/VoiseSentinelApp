import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Displays a real-time audio visualizer so users can see when they're speaking.
/// Supports [AudioVisualizerStyle.bars] (bottom-up bars) and [AudioVisualizerStyle.waveform]
/// (center-expanding bars + smooth line).
enum AudioVisualizerStyle {
  /// Classic bars growing from the bottom (oldest left, newest right).
  bars,
  /// Center-expanding bars (mirror up/down) + smooth waveform line for a modern look.
  waveform,
}

class LiveVoiceWaveform extends StatelessWidget {
  const LiveVoiceWaveform({
    super.key,
    required this.amplitudes,
    this.height = 72,
    this.barCount = 40,
    this.barWidth = 5,
    this.barSpacing = 3,
    this.color,
    this.minBarHeight = 3,
    this.style = AudioVisualizerStyle.waveform,
  });

  /// Latest amplitude values (0.0 = silence, 1.0 = max). Index 0 = oldest, last = newest.
  final List<double> amplitudes;
  final double height;
  final int barCount;
  final double barWidth;
  final double barSpacing;
  final Color? color;
  final double minBarHeight;
  final AudioVisualizerStyle style;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppTheme.primaryBlue;
    final start = amplitudes.length > barCount ? amplitudes.length - barCount : 0;

    if (style == AudioVisualizerStyle.waveform) {
      return SizedBox(
        height: height,
        child: CustomPaint(
          painter: _WaveformPainter(
            amplitudes: amplitudes,
            start: start,
            barCount: barCount,
            color: color,
            height: height,
            barWidth: barWidth,
            barSpacing: barSpacing,
            minBarHeight: minBarHeight,
          ),
          size: Size(double.infinity, height),
        ),
      );
    }

    // Original bars style (bottom-up)
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(barCount, (i) {
          final srcIndex = start + i;
          double value = 0.0;
          if (srcIndex < amplitudes.length) {
            value = amplitudes[srcIndex].clamp(0.0, 1.0);
          }
          final barHeight = minBarHeight + value * (height - minBarHeight * 2);
          return Container(
            margin: EdgeInsets.only(right: i < barCount - 1 ? barSpacing : 0),
            width: barWidth,
            height: barHeight.clamp(minBarHeight, height - 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(barWidth / 2),
            ),
          );
        }),
      ),
    );
  }
}

/// Paints center-expanding bars and a smooth waveform line.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.amplitudes,
    required this.start,
    required this.barCount,
    required this.color,
    required this.height,
    required this.barWidth,
    required this.barSpacing,
    required this.minBarHeight,
  });

  final List<double> amplitudes;
  final int start;
  final int barCount;
  final Color color;
  final double height;
  final double barWidth;
  final double barSpacing;
  final double minBarHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final totalBarWidth = barCount * (barWidth + barSpacing) - barSpacing;
    final offsetX = (size.width - totalBarWidth) / 2 + (barWidth + barSpacing) / 2;

    // 1) Center-expanding bars (mirror up and down)
    for (var i = 0; i < barCount; i++) {
      final srcIndex = start + i;
      double value = 0.0;
      if (srcIndex < amplitudes.length) {
        value = amplitudes[srcIndex].clamp(0.0, 1.0);
      }
      final halfBarHeight = math.max(
        minBarHeight / 2,
        (value * (height * 0.45)),
      );
      final left = offsetX + i * (barWidth + barSpacing) - barWidth / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, centerY - halfBarHeight, barWidth, halfBarHeight * 2),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, Paint()..color = color);
    }

    // 2) Smooth waveform line: fill below the curve, then stroke the top curve only
    if (amplitudes.length < 2) return;
    final fillPath = Path();
    final linePath = Path();
    for (var i = 0; i < barCount; i++) {
      final srcIndex = start + i;
      if (srcIndex >= amplitudes.length) continue;
      final value = amplitudes[srcIndex].clamp(0.0, 1.0);
      final x = offsetX + i * (barWidth + barSpacing);
      final y = centerY - math.max(2.0, value * (height * 0.4));
      if (i == 0) {
        fillPath.moveTo(x, centerY);
        fillPath.lineTo(x, y);
        linePath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
        linePath.lineTo(x, y);
      }
    }
    fillPath.lineTo(offsetX + (barCount - 1) * (barWidth + barSpacing), centerY);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
        oldDelegate.start != start ||
        oldDelegate.barCount != barCount;
  }
}

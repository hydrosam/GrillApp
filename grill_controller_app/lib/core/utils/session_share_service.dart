import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/cook_session.dart';
import '../../domain/entities/temperature_reading.dart';

class SessionShareService {
  Future<File> buildGraphic(
    CookSession session, {
    bool transparentBackground = false,
  }) async {
    const width = 1600;
    const height = 900;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      const ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    final size = const ui.Size(width.toDouble(), height.toDouble());

    final backgroundPaint = ui.Paint()
      ..color = transparentBackground
          ? const ui.Color(0x00000000)
          : const ui.Color(0xFFF7F1E6);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    final titleStyle = ui.TextStyle(
      color: const ui.Color(0xFF2B1D0E),
      fontSize: 42,
      fontWeight: ui.FontWeight.w700,
    );
    final bodyStyle = ui.TextStyle(
      color: const ui.Color(0xFF6B4C30),
      fontSize: 24,
    );

    _drawText(
      canvas,
      'Cook Session Snapshot',
      const ui.Offset(80, 60),
      titleStyle,
    );
    _drawText(
      canvas,
      '${session.startTime.month}/${session.startTime.day}/${session.startTime.year}  •  ${session.program?.name ?? 'Manual cook'}',
      const ui.Offset(80, 118),
      bodyStyle,
    );
    _drawText(
      canvas,
      session.notes ?? 'No notes captured for this cook.',
      const ui.Offset(80, 158),
      bodyStyle.copyWith(fontSize: 20),
      maxWidth: 760,
    );

    final chartRect = const ui.Rect.fromLTWH(80, 250, 1440, 500);
    _drawChart(canvas, chartRect, session.readings);
    _drawFooter(canvas, session, const ui.Offset(80, 790), bodyStyle);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List() ?? Uint8List(0);

    final tempDir = await getTemporaryDirectory();
    final filename = transparentBackground
        ? 'cook-session-overlay-${session.id}.png'
        : 'cook-session-card-${session.id}.png';
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> share(
    CookSession session, {
    bool transparentBackground = false,
  }) async {
    final file = await buildGraphic(
      session,
      transparentBackground: transparentBackground,
    );

    await SharePlus.instance.share(
      ShareParams(
        text: 'Grill session: ${session.program?.name ?? 'Manual cook'}',
        files: [XFile(file.path)],
      ),
    );
  }

  void _drawChart(
    ui.Canvas canvas,
    ui.Rect rect,
    List<TemperatureReading> readings,
  ) {
    final axisPaint = ui.Paint()
      ..color = const ui.Color(0xFFB88A5A)
      ..strokeWidth = 2;
    final gridPaint = ui.Paint()
      ..color = const ui.Color(0xFFE3D1BB)
      ..strokeWidth = 1;

    for (var row = 0; row <= 4; row++) {
      final y = rect.top + (rect.height / 4) * row;
      canvas.drawLine(ui.Offset(rect.left, y), ui.Offset(rect.right, y), gridPaint);
    }
    canvas.drawRect(rect, axisPaint..style = ui.PaintingStyle.stroke);

    if (readings.isEmpty) {
      _drawText(
        canvas,
        'No temperature history available',
        ui.Offset(rect.left + 24, rect.top + 24),
        ui.TextStyle(
          color: const ui.Color(0xFF7D6044),
          fontSize: 26,
        ),
      );
      return;
    }

    final grouped = <ProbeType, List<TemperatureReading>>{};
    for (final reading in readings) {
      grouped.putIfAbsent(reading.type, () => []).add(reading);
    }

    final sortedReadings = [...readings]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final minTime = sortedReadings.first.timestamp;
    final maxTime = sortedReadings.last.timestamp;
    final minTemp = readings
        .map((reading) => reading.temperature)
        .reduce(math.min);
    final maxTemp = readings
        .map((reading) => reading.temperature)
        .reduce(math.max);
    final spanSeconds =
        math.max(maxTime.difference(minTime).inSeconds.toDouble(), 1.0);
    final spanTemp = math.max(maxTemp - minTemp, 1.0);

    final palette = <ProbeType, ui.Color>{
      ProbeType.grill: const ui.Color(0xFFD95D39),
      ProbeType.food1: const ui.Color(0xFF2D6A4F),
      ProbeType.food2: const ui.Color(0xFF3A86FF),
      ProbeType.food3: const ui.Color(0xFF8C5E58),
    };

    grouped.forEach((probeType, probeReadings) {
      if (probeReadings.length < 2) {
        return;
      }

      final path = ui.Path();
      for (var index = 0; index < probeReadings.length; index++) {
        final reading = probeReadings[index];
        final x = rect.left +
            (reading.timestamp.difference(minTime).inSeconds / spanSeconds) *
                rect.width;
        final normalized =
            (reading.temperature - minTemp) / spanTemp;
        final y = rect.bottom - (normalized * rect.height);
        if (index == 0) {
          path.moveTo(x.toDouble(), y.toDouble());
        } else {
          path.lineTo(x.toDouble(), y.toDouble());
        }
      }

      final paint = ui.Paint()
        ..color = palette[probeType] ?? const ui.Color(0xFF6B4C30)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = ui.StrokeCap.round;
      canvas.drawPath(path, paint);
    });

    _drawLegend(canvas, rect.topLeft.translate(20, 20), palette);
  }

  void _drawLegend(
    ui.Canvas canvas,
    ui.Offset offset,
    Map<ProbeType, ui.Color> palette,
  ) {
    var currentY = offset.dy;
    for (final entry in palette.entries) {
      final paint = ui.Paint()..color = entry.value;
      canvas.drawCircle(ui.Offset(offset.dx, currentY + 10), 8, paint);
      _drawText(
        canvas,
        entry.key.name.toUpperCase(),
        ui.Offset(offset.dx + 22, currentY),
        ui.TextStyle(
          color: const ui.Color(0xFF5A412A),
          fontSize: 20,
          fontWeight: ui.FontWeight.w600,
        ),
      );
      currentY += 30;
    }
  }

  void _drawFooter(
    ui.Canvas canvas,
    CookSession session,
    ui.Offset offset,
    ui.TextStyle style,
  ) {
    final duration = (session.endTime ?? DateTime.now()).difference(session.startTime);
    final lines = [
      'Duration: ${duration.inHours}h ${(duration.inMinutes % 60)}m',
      'Readings: ${session.readings.length}',
      'Device: ${session.deviceId}',
    ];

    for (var index = 0; index < lines.length; index++) {
      _drawText(
        canvas,
        lines[index],
        offset.translate(0, index * 30),
        style,
      );
    }
  }

  void _drawText(
    ui.Canvas canvas,
    String text,
    ui.Offset offset,
    ui.TextStyle style, {
    double? maxWidth,
  }) {
    final paragraphStyle = ui.ParagraphStyle(
      maxLines: maxWidth == null ? 1 : 4,
      ellipsis: maxWidth == null ? null : '…',
    );
    final builder = ui.ParagraphBuilder(paragraphStyle)..pushStyle(style);
    builder.addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth ?? 1200));
    canvas.drawParagraph(paragraph, offset);
  }
}

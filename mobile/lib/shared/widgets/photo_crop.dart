import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

Future<Uint8List?> cropPhoto(
  BuildContext context,
  Uint8List bytes, {
  required int width,
  required int height,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final ui.Image image;
  try {
    image = (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
  try {
    if (!context.mounted) return null;
    final crop = await showDialog<_Crop>(
      context: context,
      builder: (_) => _CropDialog(image: image, ratio: width / height),
    );
    if (crop == null) return null;
    final recorder = ui.PictureRecorder();
    _draw(
      Canvas(recorder),
      Size(width.toDouble(), height.toDouble()),
      image,
      crop,
    );
    final picture = recorder.endRecording();
    try {
      final result = await picture.toImage(width, height);
      try {
        final png = await result.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) throw StateError('No se pudo preparar la foto.');
        return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
      } finally {
        result.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    image.dispose();
  }
}

typedef _Crop = ({double zoom, double x, double y, int turns});

void _draw(Canvas canvas, Size size, ui.Image image, _Crop crop) {
  final sideways = crop.turns.isOdd;
  final width = sideways ? image.height : image.width;
  final height = sideways ? image.width : image.height;
  final scale = math.max(size.width / width, size.height / height) * crop.zoom;
  canvas.save();
  canvas.clipRect(Offset.zero & size);
  canvas.translate(
    size.width / 2 + crop.x * (width * scale - size.width) / 2,
    size.height / 2 + crop.y * (height * scale - size.height) / 2,
  );
  canvas.rotate(crop.turns * math.pi / 2);
  canvas.scale(scale);
  canvas.drawImage(
    image,
    Offset(-image.width / 2, -image.height / 2),
    Paint()..filterQuality = FilterQuality.medium,
  );
  canvas.restore();
}

class _CropPainter extends CustomPainter {
  const _CropPainter(this.image, this.crop);
  final ui.Image image;
  final _Crop crop;
  @override
  void paint(Canvas canvas, Size size) => _draw(canvas, size, image, crop);
  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image || old.crop != crop;
}

class _CropDialog extends StatefulWidget {
  const _CropDialog({required this.image, required this.ratio});
  final ui.Image image;
  final double ratio;
  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  double zoom = 1, x = 0, y = 0;
  int turns = 0;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Encuadra la foto'),
    scrollable: true,
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: widget.ratio,
            child: CustomPaint(
              painter: _CropPainter(widget.image, (
                zoom: zoom,
                x: x,
                y: y,
                turns: turns,
              )),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.rotate_right),
            label: const Text('Girar 90°'),
            onPressed: () => setState(() {
              turns = (turns + 1) % 4;
              x = 0;
              y = 0;
            }),
          ),
          const Text('Ampliar'),
          Slider(
            value: zoom,
            min: 1,
            max: 4,
            onChanged: (v) => setState(() => zoom = v),
          ),
          const Text('Mover horizontalmente'),
          Slider(
            value: x,
            min: -1,
            max: 1,
            onChanged: (v) => setState(() => x = v),
          ),
          const Text('Mover verticalmente'),
          Slider(
            value: y,
            min: -1,
            max: 1,
            onChanged: (v) => setState(() => y = v),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.pop(context, (zoom: zoom, x: x, y: y, turns: turns)),
        child: const Text('Confirmar encuadre'),
      ),
    ],
  );
}

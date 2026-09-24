// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;

class WebCapturedDocument {
  const WebCapturedDocument({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

Future<WebCapturedDocument?> captureWebDocument() async {
  final devices = html.window.navigator.mediaDevices;
  if (devices == null) {
    throw StateError('This browser does not support camera capture. Import an image instead.');
  }
  final stream = await devices.getUserMedia({
    'audio': false,
    'video': {
      'facingMode': {'ideal': 'environment'},
      'width': {'ideal': 1920},
      'height': {'ideal': 1080},
    },
  });
  final result = Completer<WebCapturedDocument?>();
  final overlay = html.DivElement()
    ..style.cssText = 'position:fixed;inset:0;z-index:2147483647;display:flex;'
        'flex-direction:column;background:#07111f;color:#fff;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;';
  final header = html.DivElement()
    ..style.cssText = 'display:flex;align-items:center;justify-content:space-between;padding:18px 20px 12px;font-weight:700;'
    ..text = 'Capture document';
  final close = html.ButtonElement()
    ..text = 'Cancel'
    ..style.cssText = 'border:0;background:transparent;color:#fff;font:600 15px inherit;padding:8px;cursor:pointer;';
  header.append(close);
  final video = html.VideoElement()
    ..autoplay = true
    ..muted = true
    ..setAttribute('playsinline', 'true')
    ..style.cssText = 'width:100%;flex:1;min-height:0;object-fit:contain;background:#000;';
  video.srcObject = stream;
  final footer = html.DivElement()
    ..style.cssText = 'display:flex;justify-content:center;padding:18px 20px calc(18px + env(safe-area-inset-bottom));';
  final shutter = html.ButtonElement()
    ..setAttribute('aria-label', 'Capture photo')
    ..style.cssText = 'width:68px;height:68px;border-radius:50%;border:5px solid #fff;background:#1479ff;box-shadow:0 0 0 2px rgba(255,255,255,.35);cursor:pointer;';
  footer.append(shutter);
  overlay..append(header)..append(video)..append(footer);
  html.document.body?.append(overlay);

  void dispose() {
    for (final track in stream.getTracks()) {
      track.stop();
    }
    overlay.remove();
  }

  close.onClick.listen((_) {
    if (!result.isCompleted) result.complete(null);
  });
  shutter.onClick.listen((_) {
    final width = video.videoWidth;
    final height = video.videoHeight;
    if (width <= 0 || height <= 0) return;
    final scale = 1600 / (width > height ? width : height);
    final targetWidth = scale < 1 ? (width * scale).round() : width;
    final targetHeight = scale < 1 ? (height * scale).round() : height;
    final canvas = html.CanvasElement(width: targetWidth, height: targetHeight);
    canvas.context2D.drawImageScaled(video, 0, 0, targetWidth, targetHeight);
    final encoded = canvas.toDataUrl('image/jpeg', 0.86).split(',').last;
    if (!result.isCompleted) {
      result.complete(WebCapturedDocument(
        bytes: Uint8List.fromList(base64Decode(encoded)),
        name: 'camera-scan-${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
    }
  });

  try {
    return await result.future;
  } finally {
    dispose();
  }
}

Future<WebCapturedDocument?> pickWebDocument() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/jpeg,image/png,image/webp';
  input.click();
  await input.onChange.first;
  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) return null;
  final reader = html.FileReader()..readAsArrayBuffer(file);
  await reader.onLoadEnd.first;
  final data = reader.result;
  if (data is! ByteBuffer) throw StateError('Could not read the selected image.');
  return WebCapturedDocument(
    bytes: Uint8List.fromList(Uint8List.view(data)),
    name: file.name,
  );
}

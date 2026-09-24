import 'dart:typed_data';

class WebCapturedDocument {
  const WebCapturedDocument({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

Future<WebCapturedDocument?> captureWebDocument() async => null;

Future<WebCapturedDocument?> pickWebDocument() async => null;

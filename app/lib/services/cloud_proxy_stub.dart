class CloudProxyAnswer {
  const CloudProxyAnswer({
    required this.text,
    required this.provider,
    required this.model,
    required this.latencyMs,
  });

  final String text;
  final String provider;
  final String model;
  final int latencyMs;
}

Future<CloudProxyAnswer> requestCloudFallback({
  required String task,
  required String input,
}) {
  throw UnsupportedError('Cloud fallback is only used by the web app.');
}

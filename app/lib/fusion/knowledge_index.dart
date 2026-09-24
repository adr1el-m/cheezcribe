import 'dart:convert';
import 'dart:io';

import '../legacy/legacy_models.dart';

/// A searchable, image-free copy of one processed document.
class IndexedDocument {
  const IndexedDocument({
    required this.name,
    required this.type,
    required this.archivedAt,
    required this.lines,
    required this.fields,
  });

  final String name;
  final String type;
  final DateTime archivedAt;
  final List<IndexedLine> lines;
  final List<IndexedField> fields;

  factory IndexedDocument.fromDocument(LegacyDocument doc, {DateTime? at}) =>
      IndexedDocument(
        name: doc.name,
        type: doc.documentType,
        archivedAt: at ?? DateTime.now(),
        lines: [
          for (final page in doc.pages)
            for (var i = 0; i < page.lines.length; i++)
              if (page.lines[i].text.trim().isNotEmpty)
                IndexedLine(
                  page: page.number,
                  line: i + 1,
                  text: page.lines[i].text.trim(),
                  confidence: page.lines[i].confidence,
                  box: page.lines[i].box.length >= 4
                      ? page.lines[i].box.sublist(0, 4)
                      : null,
                ),
        ],
        fields: [
          for (final f in doc.fields)
            if (f.status != FieldStatus.unreadable)
              IndexedField(
                name: f.name,
                value: (f.finalValue ??
                        f.suggestedValue ??
                        f.aiValue ??
                        f.ocrValue ??
                        '')
                    .trim(),
                page: f.page,
                line: f.lineIndex >= 0 ? f.lineIndex + 1 : null,
                record: f.recordIndex,
                verified: f.status == FieldStatus.accepted ||
                    f.status == FieldStatus.edited,
              ),
        ].where((f) => f.value.isNotEmpty).toList(),
      );

  Map<String, Object?> toJson() => {
        'v': 1,
        'name': name,
        'type': type,
        'archived_at': archivedAt.toIso8601String(),
        'lines': [
          for (final l in lines)
            [
              l.page,
              l.line,
              l.text,
              double.parse(l.confidence.toStringAsFixed(3)),
              if (l.box != null)
                ...l.box!.map((v) => double.parse(v.toStringAsFixed(4))),
            ]
        ],
        'fields': [
          for (final f in fields)
            {
              'n': f.name,
              'v': f.value,
              'p': f.page,
              if (f.line != null) 'l': f.line,
              if (f.record > 0) 'r': f.record,
              if (f.verified) 'ok': true,
            }
        ],
      };

  static IndexedDocument? tryParse(String source) {
    try {
      final json = Map<String, dynamic>.from(jsonDecode(source) as Map);
      return IndexedDocument(
        name: json['name'] as String,
        type: json['type'] as String? ?? 'Legacy record',
        archivedAt: DateTime.tryParse(json['archived_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        lines: [
          for (final raw in json['lines'] as List)
            IndexedLine(
              page: (raw[0] as num).toInt(),
              line: (raw[1] as num).toInt(),
              text: raw[2] as String,
              confidence: (raw[3] as num).toDouble(),
              box: (raw as List).length >= 8
                  ? raw.sublist(4, 8).map((v) => (v as num).toDouble()).toList()
                  : null,
            ),
        ],
        fields: [
          for (final raw in json['fields'] as List)
            IndexedField(
              name: raw['n'] as String,
              value: raw['v'] as String,
              page: (raw['p'] as num).toInt(),
              line: (raw['l'] as num?)?.toInt(),
              record: (raw['r'] as num?)?.toInt() ?? 0,
              verified: raw['ok'] == true,
            ),
        ],
      );
    } catch (_) {
      return null;
    }
  }
}

class IndexedLine {
  const IndexedLine({
    required this.page,
    required this.line,
    required this.text,
    required this.confidence,
    this.box,
  });
  final int page;
  final int line;
  final String text;
  final double confidence;
  final List<double>? box;
}

class IndexedField {
  const IndexedField({
    required this.name,
    required this.value,
    required this.page,
    this.line,
    this.record = 0,
    this.verified = false,
  });
  final String name;
  final String value;
  final int page;
  final int? line;
  final int record;
  final bool verified;
}

/// Storage for the knowledge index. Source images are never stored.
abstract class KnowledgeStore {
  static const maxDocuments = 24;

  Future<void> save(IndexedDocument document);
  Future<List<IndexedDocument>> list();
  Future<void> clear();
}

/// One JSON file per document in the app support directory.
class FileKnowledgeStore implements KnowledgeStore {
  FileKnowledgeStore({Future<Directory> Function()? directory})
      : _directory = directory ?? _defaultDirectory;

  final Future<Directory> Function() _directory;

  /// App-private, persistent storage without a native plugin. The Dart temp
  /// directory sits inside the app container on both platforms (iOS `tmp/`,
  /// Android `cache/`), so its parent is the container root.
  static Future<Directory> _defaultDirectory() async {
    final container = Directory.systemTemp.absolute.parent.path;
    final base = Platform.isAndroid
        ? '$container/files'
        : '$container/Library/Application Support';
    return Directory('$base/knowledge_index');
  }

  Future<Directory> _dir() async {
    final dir = await _directory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _fileName(String name) =>
      '${name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}_'
      '${name.hashCode.toUnsigned(32).toRadixString(16)}.json';

  @override
  Future<void> save(IndexedDocument document) async {
    final dir = await _dir();
    await File('${dir.path}/${_fileName(document.name)}')
        .writeAsString(jsonEncode(document.toJson()), flush: true);
    final files = await _files(dir);
    if (files.length > KnowledgeStore.maxDocuments) {
      files.sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      for (final f in files.take(files.length - KnowledgeStore.maxDocuments)) {
        await f.delete();
      }
    }
  }

  @override
  Future<List<IndexedDocument>> list() async {
    final dir = await _dir();
    final docs = <IndexedDocument>[];
    for (final f in await _files(dir)) {
      final doc = IndexedDocument.tryParse(await f.readAsString());
      if (doc != null) docs.add(doc);
    }
    docs.sort((a, b) => b.archivedAt.compareTo(a.archivedAt));
    return docs;
  }

  @override
  Future<void> clear() async {
    final dir = await _dir();
    for (final f in await _files(dir)) {
      await f.delete();
    }
  }

  Future<List<File>> _files(Directory dir) async => [
        await for (final e in dir.list())
          if (e is File && e.path.endsWith('.json')) e,
      ];
}

class MemoryKnowledgeStore implements KnowledgeStore {
  final _docs = <String, IndexedDocument>{};

  @override
  Future<void> save(IndexedDocument document) async =>
      _docs[document.name] = document;

  @override
  Future<List<IndexedDocument>> list() async => _docs.values.toList()
    ..sort((a, b) => b.archivedAt.compareTo(a.archivedAt));

  @override
  Future<void> clear() async => _docs.clear();
}

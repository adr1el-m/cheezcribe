import Flutter
import UIKit
import PDFKit
import Vision
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var documentBridge: LegacyDocumentBridge?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "dev.appcon.legacylens/document",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    documentBridge = LegacyDocumentBridge(channel: channel)
  }
}

private final class LegacyDocumentBridge: NSObject, UIDocumentPickerDelegate {
  private var pendingImport: FlutterResult?
  private var pendingExport: FlutterResult?
  private var exportFileURL: URL?

  init(channel: FlutterMethodChannel) {
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(FlutterError(code: "unavailable", message: "Document bridge unavailable", details: nil)); return }
      switch call.method {
      case "pickAndRecognize": self.pick(result)
      case "recognizeSample":
        guard let bytes = call.arguments as? FlutterStandardTypedData else {
          result(FlutterError(code: "sample", message: "Demo sample unavailable", details: nil)); return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let output = try self.process(data: bytes.data,
              name: "synthetic_directory_1978.jpg", isPdf: false)
            DispatchQueue.main.async { result(output) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "sample", message: error.localizedDescription, details: nil))
            }
          }
        }
      case "exportFile": self.export(call.arguments, result)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func presenter() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
  }

  private func pick(_ result: @escaping FlutterResult) {
    guard pendingImport == nil, pendingExport == nil, let presenter = presenter() else {
      result(FlutterError(code: "busy", message: "A document picker is already open", details: nil)); return
    }
    pendingImport = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image, .pdf], asCopy: true)
    picker.allowsMultipleSelection = false
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  private func export(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard pendingImport == nil, pendingExport == nil, let presenter = presenter(),
          let args = arguments as? [String: String],
          let name = args["name"], let content = args["content"],
          (name.hasSuffix(".json") || name.hasSuffix(".csv")) else {
      result(FlutterError(code: "export", message: "Export is unavailable", details: nil)); return
    }
    let safeName = URL(fileURLWithPath: name).lastPathComponent
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent(safeName)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try content.write(to: url, atomically: true, encoding: .utf8)
      exportFileURL = url
      pendingExport = result
      let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
      picker.delegate = self
      presenter.present(picker, animated: true)
    } catch {
      result(FlutterError(code: "export", message: "Could not prepare export file", details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingImport?(nil)
    pendingImport = nil
    pendingExport?(false)
    pendingExport = nil
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    if let export = pendingExport {
      pendingExport = nil
      export(true)
      return
    }
    guard let callback = pendingImport else { return }
    pendingImport = nil
    guard let url = urls.first else { callback(nil); return }
    DispatchQueue.global(qos: .userInitiated).async {
      let accessible = url.startAccessingSecurityScopedResource()
      defer { if accessible { url.stopAccessingSecurityScopedResource() } }
      do {
        let data = try Data(contentsOf: url)
        if data.count > 15_000_000 { throw LegacyImportError("Choose a file under 15 MB") }
        let result = try self.process(data: data, name: url.lastPathComponent, isPdf: url.pathExtension.lowercased() == "pdf")
        DispatchQueue.main.async { callback(result) }
      } catch {
        DispatchQueue.main.async {
          callback(FlutterError(code: "import", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func process(data: Data, name: String, isPdf: Bool) throws -> [String: Any] {
    var images: [UIImage] = []
    if isPdf {
      guard let pdf = PDFDocument(data: data), pdf.pageCount > 0 else {
        throw LegacyImportError("This PDF could not be opened")
      }
      if pdf.pageCount > 5 { throw LegacyImportError("For this build, choose a PDF with five pages or fewer") }
      for index in 0..<pdf.pageCount {
        guard let page = pdf.page(at: index) else { continue }
        images.append(page.thumbnail(of: CGSize(width: 1700, height: 2200), for: .mediaBox))
      }
    } else {
      guard let image = UIImage(data: data) else { throw LegacyImportError("This image could not be opened") }
      images = [image]
    }
    var pages: [[String: Any]] = []
    for (index, image) in images.enumerated() {
      let normalized = UIGraphicsImageRenderer(size: image.size).image { _ in image.draw(at: .zero) }
      guard let jpeg = normalized.jpegData(compressionQuality: 0.88),
            let cgImage = normalized.cgImage else { continue }
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = false
      try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
      let observations = (request.results ?? []).sorted {
        if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.02 {
          return $0.boundingBox.midY > $1.boundingBox.midY
        }
        return $0.boundingBox.minX < $1.boundingBox.minX
      }
      let lines: [[String: Any]] = observations.compactMap { observation in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let box = observation.boundingBox
        let width = CGFloat(cgImage.width), height = CGFloat(cgImage.height)
        let expanded = CGRect(x: box.minX * width, y: (1 - box.maxY) * height,
                              width: box.width * width, height: box.height * height)
          .insetBy(dx: -12, dy: -12)
          .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        let crop = cgImage.cropping(to: expanded).flatMap {
          UIImage(cgImage: $0).jpegData(compressionQuality: 0.85)
        }
        return [
          "text": candidate.string,
          "confidence": Double(candidate.confidence),
          "box": [Double(box.minX), Double(1 - box.maxY), Double(box.width), Double(box.height)],
          "crop": crop.map { FlutterStandardTypedData(bytes: $0) } ?? FlutterStandardTypedData(bytes: Data()),
        ]
      }
      pages.append(["number": index + 1, "image": FlutterStandardTypedData(bytes: jpeg), "lines": lines])
    }
    if pages.isEmpty { throw LegacyImportError("No page images could be read") }
    return ["name": name, "pages": pages]
  }
}

private struct LegacyImportError: LocalizedError {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}

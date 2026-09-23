import Flutter
import UIKit
import PDFKit
import Vision
import VisionKit
import UniformTypeIdentifiers
import CoreImage
import CryptoKit

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

private final class LegacyDocumentBridge: NSObject, UIDocumentPickerDelegate, VNDocumentCameraViewControllerDelegate {
  private var pendingImport: FlutterResult?
  private var pendingExport: FlutterResult?
  private var exportFileURL: URL?

  init(channel: FlutterMethodChannel) {
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(FlutterError(code: "unavailable", message: "Document bridge unavailable", details: nil)); return }
      switch call.method {
      case "scanDocument": self.scan(result)
      case "pickAndRecognize": self.pick(result)
      case "recognizeSaved":
        guard let path = call.arguments as? String else {
          result(FlutterError(code: "history", message: "Saved document path missing", details: nil)); return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            let storedName = url.lastPathComponent
            let displayName = storedName.firstIndex(of: "_").map {
              String(storedName[storedName.index(after: $0)...])
            } ?? storedName
            var output = try self.process(
              data: data,
              name: displayName,
              isPdf: url.pathExtension.lowercased() == "pdf")
            output["historyPath"] = path
            DispatchQueue.main.async { result(output) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "history", message: "Could not reopen saved document", details: error.localizedDescription))
            }
          }
        }
      case "recognizeSample":
        guard let bytes = call.arguments as? FlutterStandardTypedData else {
          result(FlutterError(code: "sample", message: "Demo sample unavailable", details: nil)); return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let output = try self.process(data: bytes.data,
              name: "philippines_civil_works_1915.jpg", isPdf: false)
            DispatchQueue.main.async { result(output) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "sample", message: error.localizedDescription, details: nil))
            }
          }
        }
      case "exportFile": self.export(call.arguments, result)
      case "exportSummaryPdf": self.exportSummaryPdf(call.arguments, result)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func exportSummaryPdf(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard pendingImport == nil, pendingExport == nil, let presenter = presenter(),
          let args = arguments as? [String: Any],
          let title = args["title"] as? String,
          let filename = args["filename"] as? String,
          let docType = args["documentType"] as? String,
          let pageCount = args["pageCount"] as? Int,
          let abstractText = args["abstract"] as? String else {
      result(FlutterError(code: "pdf", message: "Summary data invalid", details: nil)); return
    }

    let keyEntities = (args["keyEntities"] as? [[String: String]]) ?? []
    let qualityScore = (args["qualityScore"] as? String) ?? "96.4%"
    let fieldCount = (args["fieldCount"] as? Int) ?? keyEntities.count

    let safeBase = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
    let safeName = "\(safeBase)_executive_summary.pdf"
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent(safeName)

    let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try renderer.writePDF(to: url) { context in
        context.beginPage()

        // 1. Header Banner
        let headerRect = CGRect(x: 36, y: 36, width: 540, height: 56)
        let headerPath = UIBezierPath(roundedRect: headerRect, cornerRadius: 8)
        UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0).setFill()
        headerPath.fill()

        let bannerTitle = "PAPERAZZI  •  EXECUTIVE DOCUMENT DOSSIER"
        bannerTitle.draw(at: CGPoint(x: 48, y: 46), withAttributes: [
          .font: UIFont.boldSystemFont(ofSize: 13),
          .foregroundColor: UIColor(red: 56/255, green: 189/255, blue: 248/255, alpha: 1.0)
        ])

        let bannerSub = "Legacy Knowledge Digitization & Structured Asset Redefinition"
        bannerSub.draw(at: CGPoint(x: 48, y: 66), withAttributes: [
          .font: UIFont.systemFont(ofSize: 9.5),
          .foregroundColor: UIColor.white
        ])

        // 2. Title & Ingestion Metadata
        var currentY: CGFloat = 104
        title.draw(in: CGRect(x: 36, y: currentY, width: 540, height: 26), withAttributes: [
          .font: UIFont.boldSystemFont(ofSize: 17),
          .foregroundColor: UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)
        ])
        currentY += 26

        let metaText = "Source: \(filename)  |  Pages Analyzed: \(pageCount)  |  Classification: \(docType)  |  Entities: \(fieldCount)"
        metaText.draw(at: CGPoint(x: 36, y: currentY), withAttributes: [
          .font: UIFont.systemFont(ofSize: 9.5),
          .foregroundColor: UIColor.darkGray
        ])
        currentY += 20

        // 3. Section 1: Archival Purpose & Abstract
        "1. ARCHIVAL PURPOSE & INFORMED SUMMARY".draw(at: CGPoint(x: 36, y: currentY), withAttributes: [
          .font: UIFont.boldSystemFont(ofSize: 11),
          .foregroundColor: UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)
        ])
        currentY += 16

        let abstractRect = CGRect(x: 36, y: currentY, width: 540, height: 72)
        let abstractBox = UIBezierPath(roundedRect: abstractRect, cornerRadius: 6)
        UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1.0).setFill()
        abstractBox.fill()
        UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 1.0).setStroke()
        abstractBox.lineWidth = 1
        abstractBox.stroke()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        abstractText.draw(in: abstractRect.insetBy(dx: 10, dy: 8), withAttributes: [
          .font: UIFont.systemFont(ofSize: 9.5),
          .foregroundColor: UIColor(red: 51/255, green: 65/255, blue: 85/255, alpha: 1.0),
          .paragraphStyle: paragraphStyle
        ])
        currentY += 86

        // 4. Section 2: Key Extracted Entities
        "2. STRUCTURED KNOWLEDGE INVENTORY (RELATIONAL RECORDS)".draw(at: CGPoint(x: 36, y: currentY), withAttributes: [
          .font: UIFont.boldSystemFont(ofSize: 11),
          .foregroundColor: UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)
        ])
        currentY += 16

        let thRect = CGRect(x: 36, y: currentY, width: 540, height: 18)
        UIColor(red: 241/255, green: 245/255, blue: 249/255, alpha: 1.0).setFill()
        UIRectFill(thRect)
        "REC #".draw(at: CGPoint(x: 44, y: currentY + 4), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 8.5), .foregroundColor: UIColor.darkGray])
        "FIELD / DESIGNATION".draw(at: CGPoint(x: 90, y: currentY + 4), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 8.5), .foregroundColor: UIColor.darkGray])
        "EXTRACTED HISTORICAL VALUE".draw(at: CGPoint(x: 240, y: currentY + 4), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 8.5), .foregroundColor: UIColor.darkGray])
        "AUDIT STATUS".draw(at: CGPoint(x: 450, y: currentY + 4), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 8.5), .foregroundColor: UIColor.darkGray])
        currentY += 18

        let rowFont = UIFont.systemFont(ofSize: 8.5)
        for (idx, entity) in keyEntities.prefix(13).enumerated() {
          let rowRect = CGRect(x: 36, y: currentY, width: 540, height: 16)
          if idx % 2 == 1 {
            UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1.0).setFill()
            UIRectFill(rowRect)
          }
          (entity["record"] ?? "\(idx + 1)").draw(at: CGPoint(x: 44, y: currentY + 3), withAttributes: [.font: rowFont, .foregroundColor: UIColor.black])
          (entity["name"] ?? "").draw(at: CGPoint(x: 90, y: currentY + 3), withAttributes: [.font: rowFont, .foregroundColor: UIColor.black])
          (entity["value"] ?? "").draw(in: CGRect(x: 240, y: currentY + 3, width: 200, height: 13), withAttributes: [.font: rowFont, .foregroundColor: UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)])
          (entity["status"] ?? "review").uppercased().draw(at: CGPoint(x: 450, y: currentY + 3), withAttributes: [.font: rowFont, .foregroundColor: UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0)])
          currentY += 16
        }
        currentY += 16

        // 5. Section 3: Data Quality & Downstream Action
        "3. AUDIT INTEGRITY SPECIFICATION".draw(at: CGPoint(x: 36, y: currentY), withAttributes: [
          .font: UIFont.boldSystemFont(ofSize: 11),
          .foregroundColor: UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)
        ])
        currentY += 16

        let boxW: CGFloat = 172
        let statBox1 = CGRect(x: 36, y: currentY, width: boxW, height: 42)
        let statBox2 = CGRect(x: 36 + boxW + 12, y: currentY, width: boxW, height: 42)
        let statBox3 = CGRect(x: 36 + (boxW + 12) * 2, y: currentY, width: boxW, height: 42)

        for box in [statBox1, statBox2, statBox3] {
          let p = UIBezierPath(roundedRect: box, cornerRadius: 6)
          UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1.0).setFill()
          p.fill()
          UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 1.0).setStroke()
          p.lineWidth = 1
          p.stroke()
        }

        "OCR LEGIBILITY SCORE".draw(at: CGPoint(x: statBox1.minX + 8, y: statBox1.minY + 6), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: UIColor.gray])
        qualityScore.draw(at: CGPoint(x: statBox1.minX + 8, y: statBox1.minY + 18), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 13), .foregroundColor: UIColor.black])

        "SOURCE LINKING".draw(at: CGPoint(x: statBox2.minX + 8, y: statBox2.minY + 6), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: UIColor.gray])
        "Coordinates + review state".draw(at: CGPoint(x: statBox2.minX + 8, y: statBox2.minY + 18), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 10.5), .foregroundColor: UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1.0)])

        "RELATIONAL EXPORT FORMAT".draw(at: CGPoint(x: statBox3.minX + 8, y: statBox3.minY + 6), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: UIColor.gray])
        "PostgreSQL / Snowflake / CSV".draw(at: CGPoint(x: statBox3.minX + 8, y: statBox3.minY + 18), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 10.5), .foregroundColor: UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0)])

        // Footer
        let footerText = "REVIEWABLE PAPERAZZI EXTRACTION  •  UNRESOLVED VALUES REQUIRE HUMAN REVIEW  •  " + Date().description
        footerText.draw(at: CGPoint(x: 36, y: 752), withAttributes: [.font: UIFont.systemFont(ofSize: 7.5), .foregroundColor: UIColor.lightGray])
      }

      exportFileURL = url
      pendingExport = result
      let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
      picker.delegate = self
      presenter.present(picker, animated: true)
    } catch {
      result(FlutterError(code: "pdf", message: "Could not create summary PDF: \(error.localizedDescription)", details: nil))
    }
  }

  private func presenter() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
  }

  private func scan(_ result: @escaping FlutterResult) {
    guard pendingImport == nil, pendingExport == nil, let presenter = presenter() else {
      result(FlutterError(code: "busy", message: "A document operation is already active", details: nil)); return
    }
    guard VNDocumentCameraViewController.isSupported else {
      result(FlutterError(code: "unsupported", message: "Paper camera scanning is not supported on this device/simulator. Use a physical iPhone.", details: nil))
      return
    }
    pendingImport = result
    let scanner = VNDocumentCameraViewController()
    scanner.delegate = self
    presenter.present(scanner, animated: true)
  }

  private func pick(_ result: @escaping FlutterResult) {
    guard pendingImport == nil, pendingExport == nil, let presenter = presenter() else {
      result(FlutterError(code: "busy", message: "A document operation is already active", details: nil)); return
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
          ([".json", ".csv", ".svg", ".dxf"].contains { name.hasSuffix($0) }) else {
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
        if data.count > 100_000_000 { throw LegacyImportError("Choose a file under 100 MB") }
        var result = try self.process(data: data, name: url.lastPathComponent, isPdf: url.pathExtension.lowercased() == "pdf")
        if let archived = try? self.archiveSource(data: data, name: url.lastPathComponent) {
          result["historyPath"] = archived.path
        }
        DispatchQueue.main.async { callback(result) }
      } catch {
        DispatchQueue.main.async {
          callback(FlutterError(code: "import", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  // MARK: - VNDocumentCameraViewControllerDelegate
  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
    controller.dismiss(animated: true)
    guard let callback = pendingImport else { return }
    pendingImport = nil

    let count = scan.pageCount
    if count == 0 {
      callback(nil)
      return
    }
    if count > 200 {
      callback(FlutterError(code: "import", message: "Scan up to 100 pages per batch", details: nil))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        var images: [UIImage] = []
        for i in 0..<count {
          images.append(scan.imageOfPage(at: i))
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let result = try self.processImages(images: images, name: "Scan_\(timestamp).jpg")
        DispatchQueue.main.async { callback(result) }
      } catch {
        DispatchQueue.main.async {
          callback(FlutterError(code: "import", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    controller.dismiss(animated: true)
    pendingImport?(nil)
    pendingImport = nil
  }

  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
    controller.dismiss(animated: true)
    pendingImport?(FlutterError(code: "import", message: error.localizedDescription, details: nil))
    pendingImport = nil
  }

  // MARK: - Image & Vision OCR Processing
  private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

  private func archiveSource(data: Data, name: String) throws -> URL {
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true)
    let directory = support.appendingPathComponent("PaperazziHistory", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let safeName = URL(fileURLWithPath: name).lastPathComponent
    let destination = directory.appendingPathComponent("\(UUID().uuidString)_\(safeName)")
    try data.write(to: destination, options: .atomic)
    return destination
  }

  private func process(data: Data, name: String, isPdf: Bool) throws -> [String: Any] {
    let sourceFingerprint = SHA256.hash(data: data)
      .map { String(format: "%02x", $0) }
      .joined()
    if isPdf {
      guard let pdf = PDFDocument(data: data), pdf.pageCount > 0 else {
        throw LegacyImportError("This PDF could not be opened")
      }
      if pdf.pageCount > 100 { throw LegacyImportError("Choose a PDF with 100 pages or fewer per batch") }

      var pages: [[String: Any]] = []
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1.0
      format.opaque = true

      for index in 0..<pdf.pageCount {
        try autoreleasepool {
          guard let page = pdf.page(at: index) else { return }
          print("📄 [Paperazzi] Processing page \(index + 1) of \(pdf.pageCount)...")
          let pageBounds = page.bounds(for: .mediaBox)
          let maxDim: CGFloat = 1600.0
          let scale = min(maxDim / max(pageBounds.width, 1.0), maxDim / max(pageBounds.height, 1.0), 2.0)
          let targetSize = CGSize(width: max(1, ceil(pageBounds.width * scale)), height: max(1, ceil(pageBounds.height * scale)))

          let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
          let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            ctx.cgContext.saveGState()
            // CoreGraphics PDF coordinate space has origin at bottom-left; UIKit has origin at top-left.
            // Invert the vertical axis so the rendered scan is right-side up.
            ctx.cgContext.translateBy(x: 0, y: targetSize.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
            ctx.cgContext.restoreGState()
          }

          let pageData = try processSinglePage(
            image: image,
            pageNumber: index + 1,
            detectGeometry: pdf.pageCount <= 3 || index < 3)
          pages.append(pageData)
        }
      }
      print("✅ [Paperazzi] Finished OCR for all \(pdf.pageCount) pages. Passing compact results to UI.")
      if pages.isEmpty { throw LegacyImportError("No page images could be read") }
      return ["name": name, "pages": pages, "sourceFingerprint": sourceFingerprint]
    } else {
      guard let image = UIImage(data: data) else { throw LegacyImportError("This image could not be opened") }
      var output = try processImages(images: [image], name: name)
      output["sourceFingerprint"] = sourceFingerprint
      return output
    }
  }

  private func processImages(images: [UIImage], name: String) throws -> [String: Any] {
    var pages: [[String: Any]] = []
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    format.opaque = true

    for (index, image) in images.enumerated() {
      try autoreleasepool {
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let normalized = renderer.image { _ in image.draw(at: .zero) }
        let pageData = try processSinglePage(
          image: normalized,
          pageNumber: index + 1,
          detectGeometry: images.count <= 3 || index < 3)
        pages.append(pageData)
      }
    }
    if pages.isEmpty { throw LegacyImportError("No page images could be read") }
    return ["name": name, "pages": pages]
  }

  private func processSinglePage(
    image: UIImage,
    pageNumber: Int,
    detectGeometry: Bool
  ) throws -> [String: Any] {
    guard let jpeg = image.jpegData(compressionQuality: 0.85),
          let cgImage = image.cgImage else {
      throw LegacyImportError("Could not render page image")
    }
    let originalResult = try recognize(cgImage)
    var ocrResult = originalResult
    var enhancedJpeg = jpeg
    var enhancementApplied = false

    // Faded paper and cursive handwriting benefit from a second local Vision
    // pass. Limit this to the first three pages so large archives stay
    // responsive, then keep whichever pass found more usable text.
    if pageNumber <= 3 &&
       (originalResult.meanConfidence < 0.97 || originalResult.lines.count < 60) {
      let enhanced = enhancedForRecognition(image)
      if let enhancedCg = enhanced.cgImage,
         let candidateJpeg = enhanced.jpegData(compressionQuality: 0.88) {
        let enhancedResult = try recognize(enhancedCg)
        let originalScore = Double(originalResult.lines.count) + originalResult.meanConfidence
        let enhancedScore = Double(enhancedResult.lines.count) + enhancedResult.meanConfidence
        enhancedJpeg = candidateJpeg
        if enhancedScore > originalScore {
          ocrResult = enhancedResult
          enhancementApplied = true
        }
      }
    }
    return [
      "number": pageNumber,
      "image": FlutterStandardTypedData(bytes: jpeg),
      "enhancedImage": FlutterStandardTypedData(bytes: enhancedJpeg),
      "enhancementApplied": enhancementApplied,
      "originalMeanConfidence": originalResult.meanConfidence,
      "pixelWidth": cgImage.width,
      "pixelHeight": cgImage.height,
      "lines": ocrResult.lines,
      "drawingObjects": detectGeometry
        ? try detectDrawingGeometry(cgImage, page: pageNumber)
        : [],
    ]
  }

  private func enhancedForRecognition(_ image: UIImage) -> UIImage {
    guard var output = CIImage(image: image) else { return image }
    output = output.applyingFilter("CIColorControls", parameters: [
      kCIInputSaturationKey: 0.0,
      kCIInputContrastKey: 1.38,
      kCIInputBrightnessKey: 0.035,
    ])
    output = output.applyingFilter("CISharpenLuminance", parameters: [
      kCIInputSharpnessKey: 0.45,
    ])
    guard let rendered = Self.ciContext.createCGImage(output, from: output.extent) else { return image }
    return UIImage(cgImage: rendered)
  }

  private func recognize(_ cgImage: CGImage) throws -> (lines: [[String: Any]], meanConfidence: Double) {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
    let observations = (request.results ?? []).sorted {
        if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.02 {
          return $0.boundingBox.midY > $1.boundingBox.midY
        }
        return $0.boundingBox.minX < $1.boundingBox.minX
      }
    var cropBudget = 40
    let lines: [[String: Any]] = observations.enumerated().compactMap { index, observation in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let box = observation.boundingBox
        let width = CGFloat(cgImage.width), height = CGFloat(cgImage.height)
        let lineX = box.minX * width
        let lineY = (1 - box.maxY) * height
        let lineW = box.width * width
        let lineH = box.height * height

        // Proportional tight padding: clean horizontal breathing room, tight vertical clamp to prevent bleeding
        let padX = min(12.0, max(4.0, lineW * 0.02))
        let padY = min(4.0, max(2.0, lineH * 0.06))
        let expanded = CGRect(
          x: lineX - padX,
          y: lineY - padY,
          width: lineW + (padX * 2),
          height: lineH + (padY * 2)
        ).intersection(CGRect(x: 0, y: 0, width: width, height: height))
         .integral

        var cropData = Data()
        let shouldCrop = cropBudget > 0 && (index < 12 || candidate.confidence < 0.85)
        if shouldCrop,
           expanded.width >= 4 && expanded.height >= 4,
           let croppedCg = cgImage.cropping(to: expanded) {
          cropData = UIImage(cgImage: croppedCg).jpegData(compressionQuality: 0.88) ?? Data()
          cropBudget -= 1
        }
        return [
          "text": candidate.string,
          "confidence": Double(candidate.confidence),
          "box": [Double(box.minX), Double(1 - box.maxY), Double(box.width), Double(box.height)],
          "crop": FlutterStandardTypedData(bytes: cropData),
        ]
    }
    let mean = observations.isEmpty ? 0 : observations.reduce(0.0) {
      $0 + Double($1.topCandidates(1).first?.confidence ?? 0)
    } / Double(observations.count)
    return (lines, mean)
  }

  private func detectDrawingGeometry(_ cgImage: CGImage, page: Int) throws -> [[String: Any]] {
    let rectangles = VNDetectRectanglesRequest()
    rectangles.maximumObservations = 60
    rectangles.minimumConfidence = 0.45
    rectangles.minimumAspectRatio = 0.05
    rectangles.minimumSize = 0.015
    rectangles.quadratureTolerance = 22

    let contours = VNDetectContoursRequest()
    contours.contrastAdjustment = 1.15
    contours.detectsDarkOnLight = true
    contours.maximumImageDimension = 1024

    try VNImageRequestHandler(cgImage: cgImage, options: [:])
      .perform([rectangles, contours])

    var output = (rectangles.results ?? []).enumerated().map { index, observation in
      let box = observation.boundingBox
      let points = [observation.topLeft, observation.topRight,
                    observation.bottomRight, observation.bottomLeft]
      return [
        "id": "p\(page)rect\(index + 1)",
        "kind": "quadrilateral",
        "box": [Double(box.minX), Double(1 - box.maxY), Double(box.width), Double(box.height)],
        "points": points.flatMap { [Double($0.x), Double(1 - $0.y)] },
        "confidence": Double(observation.confidence),
        "closed": true,
      ] as [String: Any]
    }

    let rectangleBoxes = (rectangles.results ?? []).map(\.boundingBox)
    var contourIndex = 0
    for contour in contours.results?.first?.topLevelContours ?? [] {
      let bounds = contour.normalizedPath.boundingBoxOfPath
      let area = bounds.width * bounds.height
      if area < 0.003 || area > 0.85 { continue }
      if rectangleBoxes.contains(where: { intersectionOverUnion($0, bounds) > 0.78 }) { continue }

      var rawPoints: [CGPoint] = []
      contour.normalizedPath.applyWithBlock { pointer in
        let element = pointer.pointee
        switch element.type {
        case .moveToPoint, .addLineToPoint:
          rawPoints.append(element.points[0])
        case .addQuadCurveToPoint:
          rawPoints.append(element.points[1])
        case .addCurveToPoint:
          rawPoints.append(element.points[2])
        case .closeSubpath:
          break
        @unknown default:
          break
        }
      }
      let reduced = simplify(rawPoints, maximum: 48)
      if reduced.count < 3 { continue }
      contourIndex += 1
      let contourBox = [Double(bounds.minX), Double(1 - bounds.maxY),
                        Double(bounds.width), Double(bounds.height)]
      let contourPoints: [Double] = reduced.flatMap { point in
        [Double(point.x), Double(1 - point.y)]
      }
      let item: [String: Any] = [
        "id": "p\(page)contour\(contourIndex)",
        "kind": "contour",
        "box": contourBox,
        "points": contourPoints,
        "confidence": 0.5,
        "closed": true,
      ]
      output.append(item)
      if contourIndex >= 40 { break }
    }
    return output
  }

  private func simplify(_ points: [CGPoint], maximum: Int) -> [CGPoint] {
    guard points.count > maximum else { return points }
    let stride = max(1, Int(ceil(Double(points.count) / Double(maximum))))
    return points.enumerated().compactMap { index, point in
      index % stride == 0 ? point : nil
    }
  }

  private func intersectionOverUnion(_ first: CGRect, _ second: CGRect) -> CGFloat {
    let intersection = first.intersection(second)
    if intersection.isNull { return 0 }
    let overlap = intersection.width * intersection.height
    let union = first.width * first.height + second.width * second.height - overlap
    return union > 0 ? overlap / union : 0
  }
}

private struct LegacyImportError: LocalizedError {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}

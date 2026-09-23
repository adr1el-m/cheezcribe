import Cocoa
import Vision

guard let image = NSImage(contentsOfFile: "/Users/adrielmagalona/Desktop/AppCon/docs/philippine_archival_survey_1902.jpg"),
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let cgImage = bitmap.cgImage else {
    print("Failed to load image")
    exit(1)
}

// 1. Text recognition
let textReq = VNRecognizeTextRequest()
textReq.recognitionLevel = .accurate
try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([textReq])
let lines = (textReq.results ?? []).compactMap { $0.topCandidates(1).first?.string }
print("TOTAL OCR LINES EXTRACTED: \(lines.count)")
print("Sample lines:")
for l in lines.prefix(12) {
    print("  • \(l)")
}

// 2. Rectangle detection (CAD)
let rectReq = VNDetectRectanglesRequest()
rectReq.minimumConfidence = 0.50
rectReq.minimumSize = 0.015
rectReq.maximumObservations = 40
try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([rectReq])
let rects = rectReq.results ?? []
print("TOTAL DETECTED CAD OBJECTS: \(rects.count)")
for (i, r) in rects.prefix(6).enumerated() {
    print("  • CAD Object \(i+1): confidence=\(String(format: "%.2f", r.confidence)), box=\(r.boundingBox)")
}

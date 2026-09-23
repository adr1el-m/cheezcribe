import Cocoa
import CoreGraphics
import CoreText
import Foundation

let width: CGFloat = 1700
let height: CGFloat = 2200
let bounds = CGRect(x: 0, y: 0, width: width, height: height)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: Int(width),
    height: Int(height),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Cannot create CGContext")
}

// 1. Aged Parchment / Historical Archival Paper Background
context.setFillColor(CGColor(red: 247/255, green: 243/255, blue: 232/255, alpha: 1.0))
context.fill(bounds)

// Subtle vintage paper aging vignette/border
context.setStrokeColor(CGColor(red: 215/255, green: 200/255, blue: 180/255, alpha: 0.6))
context.setLineWidth(24)
context.stroke(bounds.insetBy(dx: 12, dy: 12))

// Outer double border
context.setStrokeColor(CGColor(red: 70/255, green: 55/255, blue: 40/255, alpha: 1.0))
context.setLineWidth(5)
context.stroke(bounds.insetBy(dx: 48, dy: 48))

context.setStrokeColor(CGColor(red: 120/255, green: 100/255, blue: 80/255, alpha: 0.8))
context.setLineWidth(2)
context.stroke(bounds.insetBy(dx: 58, dy: 58))

// Helper for drawing text in flipped CoreGraphics context
func drawText(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, bold: Bool = false, color: CGColor = CGColor(red: 30/255, green: 25/255, blue: 20/255, alpha: 1.0), alignCenter: Bool = false) {
    let fontName = bold ? "Baskerville-Bold" : "Baskerville"
    let font = CTFontCreateWithName(fontName as CFString, size, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    let attrString = NSAttributedString(string: text, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attrString)
    
    context.saveGState()
    var targetX = x
    if alignCenter {
        let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        targetX = x - (textWidth / 2)
    }
    // Flip coordinates for text rendering in CGContext
    context.textPosition = CGPoint(x: targetX, y: height - y)
    CTLineDraw(line, context)
    context.restoreGState()
}

// 2. Official Archival Header
drawText("BUREAU OF INSULAR AFFAIRS  •  WAR DEPARTMENT", x: width / 2, y: 110, size: 24, bold: true, alignCenter: true)
drawText("GOVERNMENT OF THE PHILIPPINE ISLANDS", x: width / 2, y: 148, size: 38, bold: true, alignCenter: true)
drawText("CADASTRAL SURVEY & PROVINCIAL MUNICIPAL GAZETTEER", x: width / 2, y: 196, size: 28, bold: true, alignCenter: true)
drawText("OFFICIAL DISTRICT FOLIO NO. 1902-BTG-0482  •  OCTOBER 17, 1902", x: width / 2, y: 236, size: 20, color: CGColor(red: 100/255, green: 80/255, blue: 60/255, alpha: 1.0), alignCenter: true)

// Decorative divider line
context.setStrokeColor(CGColor(red: 80/255, green: 65/255, blue: 50/255, alpha: 1.0))
context.setLineWidth(3)
context.beginPath()
context.move(to: CGPoint(x: 120, y: height - 265))
context.addLine(to: CGPoint(x: width - 120, y: height - 265))
context.strokePath()

// 3. Document Summary & Administrative Topography Section
drawText("I. PROVINCIAL ADMINISTRATIVE SURVEY", x: 120, y: 310, size: 22, bold: true)

let metaBox = CGRect(x: 120, y: height - 480, width: width - 240, height: 140)
context.setFillColor(CGColor(red: 240/255, green: 234/255, blue: 220/255, alpha: 0.8))
context.fill(metaBox)
context.setStrokeColor(CGColor(red: 140/255, green: 120/255, blue: 95/255, alpha: 1.0))
context.setLineWidth(2)
context.stroke(metaBox)

drawText("Province: Batangas", x: 150, y: 365, size: 22, bold: true)
drawText("Island: Luzon", x: 600, y: 365, size: 22, bold: true)
drawText("Capital: Batangas (Lat. 13° 45\u{2032} 30\u{2033} N., Lon. 121° 03\u{2032} E.)", x: 980, y: 365, size: 22, bold: true)

drawText("Territorial Area: 1,108 sq. mi. (Mainland & 18 Dependent Islands)", x: 150, y: 410, size: 20)
drawText("Population: 311,180 Inhabitants (Civil Census Records)", x: 150, y: 450, size: 20)
drawText("Filing Date: October 17, 1902", x: 980, y: 450, size: 20, bold: true)

// 4. Directory & Cadastral Landholders Table
drawText("II. CADASTRAL LANDHOLDINGS & CITIZEN DIRECTORY", x: 120, y: 530, size: 22, bold: true)
drawText("Verified entries transcribed from the 1902 General Land Registry & Tax Rolls:", x: 120, y: 560, size: 18)

let tableTopY: CGFloat = 590
let tableWidth: CGFloat = width - 240
let rowHeight: CGFloat = 62
let headers = ["LOT NO.", "FULL NAME", "MUNICIPALITY", "LAND USE", "AREA (HA)", "YEAR"]
let colX: [CGFloat] = [120, 280, 720, 1080, 1340, 1500]

// Table Header Row
let headerRect = CGRect(x: 120, y: height - tableTopY - rowHeight, width: tableWidth, height: rowHeight)
context.setFillColor(CGColor(red: 225/255, green: 215/255, blue: 198/255, alpha: 1.0))
context.fill(headerRect)
context.setStrokeColor(CGColor(red: 60/255, green: 50/255, blue: 40/255, alpha: 1.0))
context.setLineWidth(2)
context.stroke(headerRect)

for (i, h) in headers.enumerated() {
    drawText(h, x: colX[i] + 16, y: tableTopY + 40, size: 18, bold: true)
}

// Table Data Rows
let records = [
    ("0217", "Ramon Dela Cruz", "Taal, Batangas", "Sugarcane & Coffee", "14.50 Ha", "1902"),
    ("0231", "Elena Santos", "Lipa, Batangas", "Citrus & Residential", "08.25 Ha", "1902"),
    ("0246", "Luis Mercado", "Balayan, Batangas", "Commercial Waterfront", "04.10 Ha", "1902"),
    ("0288", "Maria Reyes", "Bauan, Batangas", "Saltbeds & Fishpond", "12.80 Ha", "1902"),
    ("0315", "Andres Bautista", "Calaca, Batangas", "Timber & Abaca Plantation", "24.60 Ha", "1902"),
    ("0342", "Concepcion Ilustre", "Batangas Port", "Wharfage & Warehouse", "03.75 Ha", "1902")
]

for (rowIndex, rec) in records.enumerated() {
    let currentY = tableTopY + (CGFloat(rowIndex + 1) * rowHeight)
    let rRect = CGRect(x: 120, y: height - currentY - rowHeight, width: tableWidth, height: rowHeight)
    
    // Alternating vintage tint
    if rowIndex % 2 == 1 {
        context.setFillColor(CGColor(red: 242/255, green: 236/255, blue: 224/255, alpha: 0.9))
        context.fill(rRect)
    }
    context.setStrokeColor(CGColor(red: 170/255, green: 155/255, blue: 135/255, alpha: 0.8))
    context.setLineWidth(1.5)
    context.stroke(rRect)
    
    let values = [rec.0, rec.1, rec.2, rec.3, rec.4, rec.5]
    for (colIndex, val) in values.enumerated() {
        let isBold = (colIndex == 0 || colIndex == 1)
        drawText(val, x: colX[colIndex] + 16, y: currentY + 40, size: 18, bold: isBold)
    }
}

// 5. Engineering Cadastral Drawing / Architectural Plan (Tests VNDetectRectangles -> DXF / SVG!)
let drawingSectionY: CGFloat = 1100
drawText("III. CADASTRAL SURVEY PLAT  •  OFFICIAL BOUNDARY DELINEATION", x: 120, y: drawingSectionY, size: 22, bold: true)
drawText("Certified surveyor parcel boundaries and civil coordinates (Scale: 1:1,000):", x: 120, y: drawingSectionY + 30, size: 18)

let platBox = CGRect(x: 120, y: height - 1680, width: width - 240, height: 500)
context.setFillColor(CGColor(red: 252/255, green: 249/255, blue: 240/255, alpha: 1.0))
context.fill(platBox)
context.setStrokeColor(CGColor(red: 70/255, green: 60/255, blue: 50/255, alpha: 1.0))
context.setLineWidth(3)
context.stroke(platBox)

// Blueprint / Surveyor Grid lines (subtle)
context.setStrokeColor(CGColor(red: 200/255, green: 215/255, blue: 230/255, alpha: 0.5))
context.setLineWidth(1)
for gx in stride(from: 160, through: Int(width - 160), by: 60) {
    context.beginPath()
    context.move(to: CGPoint(x: CGFloat(gx), y: height - 1680))
    context.addLine(to: CGPoint(x: CGFloat(gx), y: height - 1180))
    context.strokePath()
}
for gy in stride(from: 1200, through: 1660, by: 60) {
    context.beginPath()
    context.move(to: CGPoint(x: 120, y: height - CGFloat(gy)))
    context.addLine(to: CGPoint(x: width - 120, y: height - CGFloat(gy)))
    context.strokePath()
}

// Crisp geometric rectangular parcels (Will be detected by Apple Vision VNDetectRectangles!)
func drawCadastralParcel(rect: CGRect, label: String, sublabel: String, fillColor: CGColor) {
    context.setFillColor(fillColor)
    context.fill(rect)
    context.setStrokeColor(CGColor(red: 20/255, green: 40/255, blue: 90/255, alpha: 1.0))
    context.setLineWidth(4)
    context.stroke(rect)
    
    // Label inside parcel
    drawText(label, x: rect.midX, y: height - rect.midY + 12, size: 18, bold: true, color: CGColor(red: 10/255, green: 30/255, blue: 80/255, alpha: 1.0), alignCenter: true)
    drawText(sublabel, x: rect.midX, y: height - rect.midY + 36, size: 14, color: CGColor(red: 40/255, green: 60/255, blue: 100/255, alpha: 1.0), alignCenter: true)
}

// Parcel 1: Lot 217 (Taal)
drawCadastralParcel(
    rect: CGRect(x: 200, y: height - 1460, width: 340, height: 220),
    label: "PARCEL LOT 0217",
    sublabel: "14.50 Ha • R. Dela Cruz",
    fillColor: CGColor(red: 230/255, green: 240/255, blue: 250/255, alpha: 0.7)
)

// Parcel 2: Lot 231 (Lipa)
drawCadastralParcel(
    rect: CGRect(x: 580, y: height - 1460, width: 380, height: 220),
    label: "PARCEL LOT 0231",
    sublabel: "08.25 Ha • E. Santos",
    fillColor: CGColor(red: 235/255, green: 245/255, blue: 235/255, alpha: 0.7)
)

// Parcel 3: Lot 246 (Balayan Waterfront)
drawCadastralParcel(
    rect: CGRect(x: 1000, y: height - 1460, width: 440, height: 220),
    label: "PARCEL LOT 0246",
    sublabel: "04.10 Ha • L. Mercado",
    fillColor: CGColor(red: 250/255, green: 245/255, blue: 230/255, alpha: 0.7)
)

// Parcel 4: Road Reserve / Municipal Right-of-Way
let roadRect = CGRect(x: 200, y: height - 1560, width: 1240, height: 60)
context.setFillColor(CGColor(red: 240/255, green: 235/255, blue: 225/255, alpha: 0.8))
context.fill(roadRect)
context.setStrokeColor(CGColor(red: 120/255, green: 40/255, blue: 30/255, alpha: 1.0))
context.setLineWidth(3)
context.stroke(roadRect)
drawText("CALLE REAL / PROVINCIAL ROAD RESERVE  (WIDTH: 20 METERS)", x: roadRect.midX, y: height - roadRect.midY + 8, size: 16, bold: true, color: CGColor(red: 120/255, green: 40/255, blue: 30/255, alpha: 1.0), alignCenter: true)

// Parcel 5: Lot 288 (Bauan Coastal)
drawCadastralParcel(
    rect: CGRect(x: 320, y: height - 1650, width: 500, height: 70),
    label: "PARCEL LOT 0288  •  BAUAN FISHERY",
    sublabel: "12.80 Ha • M. Reyes",
    fillColor: CGColor(red: 230/255, green: 245/255, blue: 250/255, alpha: 0.7)
)

// Parcel 6: Lot 315 (Calaca Timber)
drawCadastralParcel(
    rect: CGRect(x: 860, y: height - 1650, width: 460, height: 70),
    label: "PARCEL LOT 0315  •  CALACA TIMBER",
    sublabel: "24.60 Ha • A. Bautista",
    fillColor: CGColor(red: 245/255, green: 240/255, blue: 230/255, alpha: 0.7)
)

// 6. Archival Verification & Official Stamp
let stampCenter = CGPoint(x: width - 340, y: height - 1920)
context.saveGState()
context.translateBy(x: stampCenter.x, y: stampCenter.y)
context.rotate(by: -0.14) // Authentic slightly tilted stamp

let stampRect = CGRect(x: -160, y: -65, width: 320, height: 130)
context.setStrokeColor(CGColor(red: 160/255, green: 30/255, blue: 40/255, alpha: 0.85))
context.setLineWidth(4)
context.stroke(stampRect)
context.stroke(stampRect.insetBy(dx: 6, dy: 6))

let stampFont = CTFontCreateWithName("Courier-Bold" as CFString, 15, nil)
func drawStampLine(_ str: String, dy: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: stampFont,
        .foregroundColor: CGColor(red: 160/255, green: 30/255, blue: 40/255, alpha: 0.85)
    ]
    let attrStr = NSAttributedString(string: str, attributes: attrs)
    let line = CTLineCreateWithAttributedString(attrStr)
    let strWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    context.textPosition = CGPoint(x: -strWidth / 2, y: dy)
    CTLineDraw(line, context)
}

drawStampLine("BUREAU OF LANDS", dy: 24)
drawStampLine("EXAMINED & VERIFIED", dy: 4)
drawStampLine("17 OCT 1902 • MANILA", dy: -16)
drawStampLine("ARCHIVE COPY 04", dy: -36)

context.restoreGState()

// 7. Signature & Certifying Officer Block
drawText("CERTIFIED HISTORICAL SURVEY ARCHIVE", x: 120, y: 1820, size: 18, bold: true)
drawText("Surveyor in Charge: H. D. McCaskey, Mining Bureau & Insular Surveyor", x: 120, y: 1855, size: 16)
drawText("Countersigned: Luke E. Wright, Vice-Governor, Philippine Commission", x: 120, y: 1885, size: 16)
drawText("Legal Notice: Public domain archival record under 17 U.S.C. § 105. Free for open digitization & research use.", x: 120, y: 1940, size: 14, color: CGColor(red: 120/255, green: 110/255, blue: 100/255, alpha: 1.0))

// 8. Save to JPEG and PDF
guard let image = context.makeImage() else {
    fatalError("Failed to create image from context")
}

let outputPath = "/Users/adrielmagalona/Desktop/AppCon/docs/philippine_archival_survey_1902.jpg"
let url = URL(fileURLWithPath: outputPath) as CFURL
guard let destination = CGImageDestinationCreateWithURL(url, "public.jpeg" as CFString, 1, nil) else {
    fatalError("Failed to create destination")
}
let options: [CFString: Any] = [
    kCGImageDestinationLossyCompressionQuality: 0.92
]
CGImageDestinationAddImage(destination, image, options as CFDictionary)
CGImageDestinationFinalize(destination)

print("Saved JPEG: \(outputPath)")

// Save as PDF as well
let pdfPath = "/Users/adrielmagalona/Desktop/AppCon/docs/philippine_archival_survey_1902.pdf"
let pdfURL = URL(fileURLWithPath: pdfPath) as CFURL
var mediaBox = CGRect(x: 0, y: 0, width: width, height: height)
guard let pdfContext = CGContext(pdfURL, mediaBox: &mediaBox, nil) else {
    fatalError("Failed to create PDF context")
}
pdfContext.beginPage(mediaBox: &mediaBox)
pdfContext.draw(image, in: mediaBox)
pdfContext.endPage()
pdfContext.closePDF()

print("Saved PDF: \(pdfPath)")

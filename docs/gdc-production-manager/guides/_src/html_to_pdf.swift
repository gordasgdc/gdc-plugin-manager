import WebKit
import AppKit

// Convertor HTML -> PDF folosind WKWebView + NSPrintOperation (calea REALA
// de printare, care respecta page-break-after/inside din CSS si produce
// pagini A4 separate) - NU webView.createPDF(), care ignora page-break-urile
// si scoate intreaga pagina ca UN SINGUR PDF foarte inalt.
//
// RunLoop.current.run(mode:before:) in loc de un semafor blocant - un
// semafor ar bloca thread-ul principal exact cat timp WKWebView are nevoie
// de el ca sa-si termine randarea asincrona, ceea ce produce un deadlock
// garantat.

guard CommandLine.arguments.count > 2 else {
    print("Utilizare: swift html_to_pdf.swift input.html output.pdf")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let inputURL = URL(fileURLWithPath: inputPath)
let outputURL = URL(fileURLWithPath: outputPath)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// A4 la 72dpi (punctele folosite de AppKit pentru print).
let pageWidth: CGFloat = 595
let pageHeight: CGFloat = 842

let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

final class NavDelegate: NSObject, WKNavigationDelegate {
    var didFinish = false
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didFinish = true
    }
}

let navDelegate = NavDelegate()
webView.navigationDelegate = navDelegate
webView.loadFileURL(inputURL, allowingReadAccessTo: inputURL.deletingLastPathComponent())

while !navDelegate.didFinish {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
}

// Lasa un moment suplimentar ca fonturile/layout-ul sa se stabilizeze complet.
RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.3))

let printInfo = NSPrintInfo()
printInfo.paperSize = NSSize(width: pageWidth, height: pageHeight)
printInfo.topMargin = 0
printInfo.bottomMargin = 0
printInfo.leftMargin = 0
printInfo.rightMargin = 0
printInfo.horizontalPagination = .fit
printInfo.verticalPagination = .automatic
printInfo.isHorizontallyCentered = false
printInfo.isVerticallyCentered = false
printInfo.jobDisposition = .save
printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = outputURL

let printOp = webView.printOperation(with: printInfo)
printOp.showsPrintPanel = false
printOp.showsProgressPanel = false

var finished = false
final class PrintDelegate: NSObject {
    var onDone: (() -> Void)?
    @objc func printOperationDidRun(_ printOperation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        onDone?()
    }
}
let printDelegate = PrintDelegate()
printDelegate.onDone = { finished = true }

printOp.runModal(
    for: NSApp.mainWindow ?? NSWindow(),
    delegate: printDelegate,
    didRun: #selector(PrintDelegate.printOperationDidRun(_:success:contextInfo:)),
    contextInfo: nil
)

while !finished {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
}

if FileManager.default.fileExists(atPath: outputPath) {
    print("Scris \(outputPath)")
} else {
    print("Eroare: fisierul PDF nu a fost creat.")
    exit(1)
}

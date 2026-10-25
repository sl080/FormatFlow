import Cocoa
import PDFKit
import ImageIO
import UniformTypeIdentifiers
import AVFoundation

let fm = FileManager.default
struct ConversionError: LocalizedError { let message: String; var errorDescription: String? { message } }
func fail(_ text: String) -> ConversionError { ConversionError(message: text) }
let imageFormats = ["png", "jpg", "jpeg", "heic", "tiff", "tif", "bmp", "gif", "webp"]
let audioInputs = ["mp3", "wav", "wave", "m4a", "m4b", "aac", "adts", "flac", "aiff", "aif", "aifc", "caf", "au", "snd"]
let audioOutputs = ["wav", "m4a", "aac", "flac", "aiff", "caf"]
let officeFormats = ["doc", "docx", "odt", "rtf", "txt", "html", "htm", "xls", "xlsx", "ods", "csv", "ppt", "pptx", "odp"]
func unique(_ folder: URL, _ name: String, _ ext: String) -> URL {
    var u = folder.appendingPathComponent(name).appendingPathExtension(ext); var i = 2
    while fm.fileExists(atPath: u.path) { u = folder.appendingPathComponent("\(name) (\(i))").appendingPathExtension(ext); i += 1 }; return u
}
func writeImage(_ image: CGImage, to url: URL, format: String) throws {
    let types = ["png": "public.png", "jpg": "public.jpeg", "tiff": "public.tiff", "bmp": "com.microsoft.bmp", "heic": "public.heic"]
    guard let type = types[format], let dest = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil) else { throw fail("无法创建此图片格式") }
    CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { throw fail("图片保存失败") }
}
func convertAudio(_ input: URL, _ format: String, _ folder: URL) throws -> [URL] {
    guard audioOutputs.contains(format) else { throw fail("音频可转换为 WAV、M4A、AAC、FLAC、AIFF 或 CAF。MP3 目前仅支持导入。") }
    // Stage every output so failed encoding never leaves a partial file in the destination.
    let temp = fm.temporaryDirectory.appendingPathComponent("FormatFlow-Audio-" + UUID().uuidString)
    try fm.createDirectory(at: temp, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: temp) }
    let staged = temp.appendingPathComponent("audio").appendingPathExtension(format)
    let options: [String: [String]] = [
        "wav": ["-f", "WAVE", "-d", "LEI16"],
        "aiff": ["-f", "AIFF", "-d", "BEI16"],
        "caf": ["-f", "caff", "-d", "LEI16"],
        "flac": ["-f", "flac", "-d", "flac"],
        "m4a": ["-f", "m4af", "-d", "aac ", "-b", "192000"],
        "aac": ["-f", "adts", "-d", "aac ", "-b", "192000"]
    ]
    let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
    process.arguments = options[format]! + [input.path, staged.path]
    let log = temp.appendingPathComponent("audio.log"); fm.createFile(atPath: log.path, contents: nil)
    let handle = try FileHandle(forWritingTo: log); defer { try? handle.close() }
    process.standardOutput = handle; process.standardError = handle
    try process.run()
    let deadline = Date().addingTimeInterval(3600)
    while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
    if process.isRunning {
        process.terminate(); process.waitUntilExit()
        throw fail("音频转换超时，请尝试较短的文件")
    }
    guard process.terminationStatus == 0 else { throw fail("音频转换失败：文件可能损坏、受保护，或其编码/声道不受系统支持。请尝试 WAV 或 M4A。") }
    guard let audio = try? AVAudioFile(forReading: staged), audio.length > 0 else { throw fail("转换结果无法读取，未保存输出文件") }
    let out = unique(folder, input.deletingPathExtension().lastPathComponent, format)
    try fm.moveItem(at: staged, to: out)
    return [out]
}
func convert(_ input: URL, _ format: String, _ folder: URL) throws -> [URL] {
    let ext = input.pathExtension.lowercased(), base = input.deletingPathExtension().lastPathComponent
    if audioInputs.contains(ext) { return try convertAudio(input, format, folder) }
    if audioOutputs.contains(format) { throw fail("音频输出需要导入音频文件。图片和文档不能转换为音频。") }
    if imageFormats.contains(ext) {
        guard let src = CGImageSourceCreateWithURL(input as CFURL, nil) else { throw fail("无法读取图片") }
        let count = CGImageSourceGetCount(src)
        if format == "pdf" {
            let doc = PDFDocument()
            for index in 0..<count {
                guard let cg = CGImageSourceCreateImageAtIndex(src, index, nil), let page = PDFPage(image: NSImage(cgImage: cg, size: .zero)) else { throw fail("图片页面读取失败") }
                doc.insert(page, at: doc.pageCount)
            }
            let out = unique(folder, base, "pdf"); guard doc.write(to: out) else { throw fail("PDF 保存失败") }; return [out]
        }
        var result: [URL] = []
        for index in 0..<count {
            guard let image = CGImageSourceCreateImageAtIndex(src, index, nil) else { throw fail("图片解码失败") }
            let out = unique(folder, count > 1 ? "\(base)-\(index + 1)" : base, format)
            try writeImage(image, to: out, format: format); result.append(out)
        }; return result
    }
    if ext == "pdf" {
        guard let doc = PDFDocument(url: input), !doc.isLocked else { throw fail("无法读取 PDF，或文件需要密码") }
        guard format != "pdf" else { throw fail("该文件已经是 PDF") }
        var result: [URL] = []
        for index in 0..<doc.pageCount {
            guard let page = doc.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale = min(2.0, 6000.0 / max(bounds.width, bounds.height))
            let image = page.thumbnail(of: NSSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
            var rect = NSRect(origin: .zero, size: image.size)
            guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { throw fail("PDF 页面渲染失败") }
            let out = unique(folder, "\(base)-\(index + 1)", format); try writeImage(cg, to: out, format: format); result.append(out)
        }; return result
    }
    guard officeFormats.contains(ext), format == "pdf" else { throw fail("此组合暂不支持。Office 文档可转 PDF；图片和 PDF 可转图片。") }
    let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: temp, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: temp) }
    let engine = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/OfficeEngine.app/Contents/MacOS/soffice")
    guard fm.isExecutableFile(atPath: engine.path) else { throw fail("Office 转换组件缺失，请重新安装完整软件") }
    let process = Process(); process.executableURL = engine
    process.arguments = ["-env:UserInstallation=\(temp.appendingPathComponent("profile").absoluteString)", "--headless", "--convert-to", "pdf", "--outdir", temp.path, input.path]
    let log = temp.appendingPathComponent("engine.log"); fm.createFile(atPath: log.path, contents: nil)
    let handle = try FileHandle(forWritingTo: log); defer { try? handle.close() }
    process.standardOutput = handle; process.standardError = handle
    try process.run()
    let deadline = Date().addingTimeInterval(180)
    while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
    if process.isRunning { process.terminate(); throw fail("文档转换超时，请检查文件是否损坏或过大") }
    let generated = temp.appendingPathComponent(base).appendingPathExtension("pdf")
    guard process.terminationStatus == 0, let pdf = PDFDocument(url: generated), pdf.pageCount > 0 else { throw fail("Office 转换失败，请检查文件是否损坏、加密或格式不受支持") }
    let out = unique(folder, base, "pdf"); try fm.moveItem(at: generated, to: out); return [out]
}

class DropView: NSView {
    var onDrop: (([URL]) -> Void)?
    override init(frame: NSRect) { super.init(frame: frame); registerForDraggedTypes([.fileURL]) }
    required init?(coder: NSCoder) { fatalError() }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else { return false }
        onDrop?(urls); return true
    }
}
class App: NSObject, NSApplicationDelegate {
    var window: NSWindow!; var files: [URL] = []; var folder = fm.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    let log = NSTextView(); let picker = NSPopUpButton(); let destination = NSTextField(labelWithString: "")
    let start = NSButton(title: "开始转换", target: nil, action: nil)
    var controls: [NSControl] = []; var busy = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu(); let item = NSMenuItem(); menu.addItem(item); let appMenu = NSMenu(); item.submenu = appMenu
        appMenu.addItem(withTitle: "关于 FormatFlow", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(withTitle: "退出 FormatFlow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 620), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "FormatFlow · 格式工坊"; window.minSize = NSSize(width: 760, height: 580)
        let root = DropView(); root.onDrop = { [weak self] urls in self?.add(urls) }; window.contentView = root
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 18; stack.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 32), stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -32), stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 28), stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -28)])
        let title = NSTextField(labelWithString: "让格式转换，简单一点。"); title.font = .systemFont(ofSize: 28, weight: .bold); stack.addArrangedSubview(title)
        let subtitle = NSTextField(wrappingLabelWithString: "离线处理 · 批量转换 · 原文件保留\n将文件拖到窗口，或点击添加文件。"); subtitle.textColor = .secondaryLabelColor; stack.addArrangedSubview(subtitle)
        let row = NSStackView(); row.spacing = 12
        for (name, action) in [("＋ 添加文件", #selector(choose)), ("清空列表", #selector(clear))] { let b = NSButton(title: name, target: self, action: action); b.bezelStyle = .rounded; row.addArrangedSubview(b); controls.append(b) }
        row.addArrangedSubview(NSTextField(labelWithString: "转换为")); picker.addItems(withTitles: ["PDF", "PNG", "JPG", "TIFF", "BMP", "HEIC", "WAV", "M4A", "AAC", "FLAC", "AIFF", "CAF"]); row.addArrangedSubview(picker); controls.append(picker); stack.addArrangedSubview(row)
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder; log.isEditable = false; log.font = .monospacedSystemFont(ofSize: 12, weight: .regular); log.textContainerInset = NSSize(width: 12, height: 12); log.autoresizingMask = [.width]; log.isVerticallyResizable = true; log.textContainer?.widthTracksTextView = true; scroll.documentView = log; stack.addArrangedSubview(scroll); scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true; scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        let pathRow = NSStackView(); pathRow.spacing = 10; let pathButton = NSButton(title: "选择保存位置…", target: self, action: #selector(chooseFolder)); pathButton.bezelStyle = .rounded; controls.append(pathButton); pathRow.addArrangedSubview(pathButton); destination.lineBreakMode = .byTruncatingMiddle; destination.stringValue = folder.path; pathRow.addArrangedSubview(destination); stack.addArrangedSubview(pathRow)
        let bottom = NSStackView(); bottom.spacing = 12; start.target = self; start.action = #selector(run); start.bezelStyle = .rounded; start.keyEquivalent = "\r"; controls.append(start); bottom.addArrangedSubview(start)
        let reveal = NSButton(title: "打开输出文件夹", target: self, action: #selector(showFolder)); reveal.bezelStyle = .rounded; bottom.addArrangedSubview(reveal); stack.addArrangedSubview(bottom)
        let note = NSTextField(wrappingLabelWithString: "支持：图片 ↔ PDF、PNG / JPG / TIFF / BMP / HEIC 互转；Word、Excel、PowerPoint、ODF、RTF、TXT、CSV、HTML → PDF。PDF 转图片会逐页输出。音频 → WAV / M4A / AAC / FLAC / AIFF / CAF（MP3 仅导入）。暂不支持 PDF 转可编辑 Word、OCR、视频转换。")
        note.font = .systemFont(ofSize: 11); note.textColor = .secondaryLabelColor; stack.addArrangedSubview(note); note.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        log.string = "等待添加文件…\n"; window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func append(_ s: String) { log.string += s + "\n"; log.scrollToEndOfDocument(nil) }
    func add(_ urls: [URL]) { guard !busy else { return }; if files.isEmpty, let first = urls.first, audioInputs.contains(first.pathExtension.lowercased()) { picker.selectItem(withTitle: "M4A") }; for u in urls { var dir: ObjCBool = false; if fm.fileExists(atPath: u.path, isDirectory: &dir), !dir.boolValue, !files.contains(u) { files.append(u); append("＋ \(u.lastPathComponent)") } }; start.title = "开始转换（\(files.count)）" }
    @objc func choose() { let p = NSOpenPanel(); p.allowsMultipleSelection = true; p.canChooseDirectories = false; if p.runModal() == .OK { add(p.urls) } }
    @objc func clear() { files = []; log.string = "等待添加文件…\n"; start.title = "开始转换" }
    @objc func chooseFolder() { let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.canCreateDirectories = true; if p.runModal() == .OK, let u = p.url { folder = u; destination.stringValue = u.path } }
    @objc func showFolder() { NSWorkspace.shared.open(folder) }
    @objc func about() { let a = NSAlert(); a.messageText = "FormatFlow 格式工坊 1.1"; a.informativeText = "本地离线格式转换工具。音频由 macOS 系统引擎处理。\nOffice 转换由内置 LibreOffice 提供，其许可证和版权说明保留在应用 Resources/OfficeEngine.app 中。"; a.runModal() }
    @objc func run() {
        guard !files.isEmpty, !busy else { return }; busy = true; controls.forEach { $0.isEnabled = false }
        let batch = files, target = picker.titleOfSelectedItem!.lowercased(), output = folder
        append("\n开始转换 → \(target.uppercased())")
        DispatchQueue.global(qos: .userInitiated).async {
            var succeeded = 0
            for file in batch {
                DispatchQueue.main.async { self.append("处理中：\(file.lastPathComponent)") }
                do { let results = try convert(file, target, output); succeeded += 1; let names = results.map { $0.lastPathComponent }.joined(separator: "、"); DispatchQueue.main.async { self.append("✓ \(names)") } }
                catch { let message = error.localizedDescription; DispatchQueue.main.async { self.append("✕ \(file.lastPathComponent)：\(message)") } }
            }
            let count = succeeded
            DispatchQueue.main.async { self.append("\n完成：\(count) 个成功，\(batch.count - count) 个失败。输出：\(output.path)"); self.busy = false; self.controls.forEach { $0.isEnabled = true } }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { if busy { let a = NSAlert(); a.messageText = "正在转换文件"; a.informativeText = "请等待当前批次完成后退出。"; a.runModal(); return .terminateCancel }; return .terminateNow }
}
if CommandLine.arguments.count == 5 && CommandLine.arguments[1] == "--convert" {
    do { let results = try convert(URL(fileURLWithPath: CommandLine.arguments[2]), CommandLine.arguments[3], URL(fileURLWithPath: CommandLine.arguments[4])); results.forEach { print($0.path) }; exit(0) } catch { fputs(error.localizedDescription + "\n", stderr); exit(1) }
}
let app = NSApplication.shared; let delegate = App(); app.delegate = delegate; app.setActivationPolicy(.regular); app.run()

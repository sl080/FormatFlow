import Cocoa
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(calibratedRed: 0.12, green: 0.25, blue: 0.91, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 30, y: 30, width: 964, height: 964), xRadius: 220, yRadius: 220).fill()
NSColor.white.withAlphaComponent(0.18).setFill()
NSBezierPath(roundedRect: NSRect(x: 230, y: 240, width: 470, height: 590), xRadius: 45, yRadius: 45).fill()
NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: 310, y: 170, width: 470, height: 590), xRadius: 45, yRadius: 45).fill()
let p = NSBezierPath(); p.lineWidth = 36; p.lineCapStyle = .round; p.lineJoinStyle = .round
p.move(to: NSPoint(x: 410,y: 565)); p.line(to: NSPoint(x: 665,y: 565)); p.line(to: NSPoint(x: 610,y: 620)); p.move(to: NSPoint(x: 665,y: 565)); p.line(to: NSPoint(x: 610,y: 510))
p.move(to: NSPoint(x: 670,y: 360)); p.line(to: NSPoint(x: 415,y: 360)); p.line(to: NSPoint(x: 470,y: 415)); p.move(to: NSPoint(x: 415,y: 360)); p.line(to: NSPoint(x: 470,y: 305))
NSColor(calibratedRed: 0.12, green: 0.25, blue: 0.91, alpha: 1).setStroke(); p.stroke(); image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))

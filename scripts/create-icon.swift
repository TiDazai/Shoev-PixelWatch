import AppKit
let output = CommandLine.arguments[1]
let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1024,pixelsHigh:1024,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:4096,bitsPerPixel:32)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
let outer = NSBezierPath(roundedRect:NSRect(x:60,y:60,width:904,height:904),xRadius:198,yRadius:198)
NSGradient(starting:NSColor(srgbRed:0.91,green:0.92,blue:0.94,alpha:1),ending:NSColor(srgbRed:0.60,green:0.62,blue:0.67,alpha:1))!.draw(in:outer,angle:-45)
let inner = NSBezierPath(roundedRect:NSRect(x:73,y:73,width:878,height:878),xRadius:185,yRadius:185)
NSGradient(starting:NSColor(srgbRed:0.98,green:0.98,blue:0.99,alpha:1),ending:NSColor(srgbRed:0.84,green:0.85,blue:0.88,alpha:1))!.draw(in:inner,angle:90)
let inset:CGFloat = 278, far:CGFloat = 746, length:CGFloat = 140
NSColor(srgbRed:0.59,green:0.60,blue:0.66,alpha:1).setStroke()
for (x,y,dx,dy) in [(inset,inset,1.0,1.0),(far,inset,-1.0,1.0),(inset,far,1.0,-1.0),(far,far,-1.0,-1.0)] {
    let path=NSBezierPath();path.lineWidth=42;path.lineCapStyle = .round;path.lineJoinStyle = .round
    path.move(to:NSPoint(x:x,y:y+CGFloat(dy)*length));path.line(to:NSPoint(x:x,y:y));path.line(to:NSPoint(x:x+CGFloat(dx)*length,y:y));path.stroke()
}
// A pointed almond silhouette and long slit pupil read as a feline eye even
// at small app-icon sizes. Keep the original metal plate and viewfinder.
let eye = NSBezierPath()
eye.move(to:NSPoint(x:298,y:512))
eye.curve(to:NSPoint(x:726,y:512),controlPoint1:NSPoint(x:392,y:698),controlPoint2:NSPoint(x:632,y:698))
eye.curve(to:NSPoint(x:298,y:512),controlPoint1:NSPoint(x:632,y:326),controlPoint2:NSPoint(x:392,y:326))
eye.close()
NSColor(srgbRed:0.25,green:0.27,blue:0.31,alpha:1).setFill();eye.fill()
NSGraphicsContext.saveGraphicsState();eye.addClip()
let iris = NSBezierPath(ovalIn:NSRect(x:374,y:374,width:276,height:276))
NSGradient(starting:NSColor(srgbRed:0.88,green:0.76,blue:0.51,alpha:1),ending:NSColor(srgbRed:0.52,green:0.42,blue:0.25,alpha:1))!.draw(in:iris,relativeCenterPosition:NSPoint(x:-0.25,y:0.35))
// Fine radial iris fibers use the same gold family, rather than a new color.
for index in 0..<64 {
    let angle = CGFloat(index) * .pi * 2 / 64
    let fiber = NSBezierPath();fiber.lineWidth = index % 3 == 0 ? 3 : 1.5
    fiber.move(to:NSPoint(x:512+cos(angle)*78,y:512+sin(angle)*78))
    fiber.line(to:NSPoint(x:512+cos(angle)*131,y:512+sin(angle)*131))
    NSColor(srgbRed:0.40,green:0.32,blue:0.19,alpha:0.28).setStroke();fiber.stroke()
}
let pupil = NSBezierPath()
pupil.move(to:NSPoint(x:512,y:638))
pupil.curve(to:NSPoint(x:512,y:386),controlPoint1:NSPoint(x:459,y:552),controlPoint2:NSPoint(x:459,y:472))
pupil.curve(to:NSPoint(x:512,y:638),controlPoint1:NSPoint(x:565,y:472),controlPoint2:NSPoint(x:565,y:552))
pupil.close()
NSColor(srgbRed:0.08,green:0.09,blue:0.12,alpha:1).setFill();pupil.fill()
NSColor(srgbRed:0.96,green:0.96,blue:0.98,alpha:0.95).setFill()
NSBezierPath(ovalIn:NSRect(x:464,y:568,width:34,height:42)).fill()
NSColor(srgbRed:0.90,green:0.90,blue:0.93,alpha:0.65).setFill()
NSBezierPath(ovalIn:NSRect(x:543,y:427,width:13,height:17)).fill()
NSGraphicsContext.restoreGraphicsState()
NSColor(srgbRed:0.50,green:0.52,blue:0.58,alpha:1).setStroke()
eye.lineWidth = 10;eye.lineJoinStyle = .round;eye.stroke()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output))

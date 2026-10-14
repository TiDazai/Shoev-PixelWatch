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
let pixel = NSBezierPath(roundedRect:NSRect(x:446,y:446,width:132,height:132),xRadius:30,yRadius:30)
NSGradient(starting:NSColor(srgbRed:0.76,green:0.64,blue:0.40,alpha:1),ending:NSColor(srgbRed:0.52,green:0.42,blue:0.25,alpha:1))!.draw(in:pixel,angle:90)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output))

import AppKit
let output = CommandLine.arguments[1]
let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1024,pixelsHigh:1024,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:4096,bitsPerPixel:32)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
let outer = NSBezierPath(roundedRect:NSRect(x:60,y:60,width:904,height:904),xRadius:198,yRadius:198)
NSGradient(starting:NSColor(srgbRed:0.91,green:0.92,blue:0.94,alpha:1),ending:NSColor(srgbRed:0.60,green:0.62,blue:0.67,alpha:1))!.draw(in:outer,angle:-45)
let inner = NSBezierPath(roundedRect:NSRect(x:73,y:73,width:878,height:878),xRadius:185,yRadius:185)
NSColor(srgbRed:230.0/255,green:230.0/255,blue:236.0/255,alpha:1).setFill();inner.fill()
let inset:CGFloat = 278, far:CGFloat = 746, length:CGFloat = 140
NSColor(srgbRed:150.0/255,green:154.0/255,blue:168.0/255,alpha:1).setStroke()
for (x,y,dx,dy) in [(inset,inset,1.0,1.0),(far,inset,-1.0,1.0),(inset,far,1.0,-1.0),(far,far,-1.0,-1.0)] {
    let path=NSBezierPath();path.lineWidth=42;path.lineCapStyle = .round;path.lineJoinStyle = .round
    path.move(to:NSPoint(x:x,y:y+CGFloat(dy)*length));path.line(to:NSPoint(x:x,y:y));path.line(to:NSPoint(x:x+CGFloat(dx)*length,y:y));path.stroke()
}
// The sole central mark is a gold feline pupil on solid SHOEV platinum.
let pupil = NSBezierPath()
pupil.move(to:NSPoint(x:512,y:672))
pupil.curve(to:NSPoint(x:512,y:352),controlPoint1:NSPoint(x:454,y:572),controlPoint2:NSPoint(x:454,y:452))
pupil.curve(to:NSPoint(x:512,y:672),controlPoint1:NSPoint(x:570,y:452),controlPoint2:NSPoint(x:570,y:572))
pupil.close()
NSColor(srgbRed:169.0/255,green:140.0/255,blue:87.0/255,alpha:1).setFill();pupil.fill()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output))

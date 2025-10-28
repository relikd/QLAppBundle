import Foundation
import AppKit // NSBezierPath

//
//  NSBezierPath+IOS7RoundedRect
//
//  Created by Matej Dunik on 11/12/13.
//  Copyright (c) 2013 PixelCut. All rights reserved except as below:
//  This code is provided as-is, without warranty of any kind. You may use it in your projects as you wish.
//

extension NSBezierPath {
	public class func IOS7RoundedRect(_ rect: NSRect, cornerRadius: CGFloat) -> NSBezierPath {
		let path = NSBezierPath()
		let limit = min(rect.size.width, rect.size.height) / 2 / 1.52866483
		let limitedRadius = min(cornerRadius, limit)
		
		@inline(__always) func topLeft(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
			return NSPoint(x: rect.origin.x + x * limitedRadius, y: rect.origin.y + y * limitedRadius)
		}
		
		@inline(__always) func topRight(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
			return NSPoint(x: rect.origin.x + rect.size.width - x * limitedRadius, y: rect.origin.y + y * limitedRadius)
		}
		
		@inline(__always) func bottomRight(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
			return NSPoint(x: rect.origin.x + rect.size.width - x * limitedRadius, y: rect.origin.y + rect.size.height - y * limitedRadius)
		}
		
		@inline(__always) func bottomLeft(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
			return NSPoint(x: rect.origin.x + x * limitedRadius, y: rect.origin.y + rect.size.height - y * limitedRadius)
		}
		
		path.move(to: topLeft(1.52866483, 0.00000000))
		path.line(to: topRight(1.52866471, 0.00000000))
		path.curve(to: topRight(0.66993427, 0.06549600), controlPoint1: topRight(1.08849323, 0.00000000), controlPoint2: topRight(0.86840689, 0.00000000))
		path.line(to: topRight(0.63149399, 0.07491100))
		path.curve(to: topRight(0.07491176, 0.63149399), controlPoint1: topRight(0.37282392, 0.16905899), controlPoint2: topRight(0.16906013, 0.37282401))
		path.curve(to: topRight(0.00000000, 1.52866483), controlPoint1: topRight(0.00000000, 0.86840701), controlPoint2: topRight(0.00000000, 1.08849299))
		path.line(to: bottomRight(0.00000000, 1.52866471))
		path.curve(to: bottomRight(0.06549569, 0.66993493), controlPoint1: bottomRight(0.00000000, 1.08849323), controlPoint2: bottomRight(0.00000000, 0.86840689))
		path.line(to: bottomRight(0.07491111, 0.63149399))
		path.curve(to: bottomRight(0.63149399, 0.07491111), controlPoint1: bottomRight(0.16905883, 0.37282392), controlPoint2: bottomRight(0.37282392, 0.16905883))
		path.curve(to: bottomRight(1.52866471, 0.00000000), controlPoint1: bottomRight(0.86840689, 0.00000000), controlPoint2: bottomRight(1.08849323, 0.00000000))
		path.line(to: bottomLeft(1.52866483, 0.00000000))
		path.curve(to: bottomLeft(0.66993397, 0.06549569), controlPoint1: bottomLeft(1.08849299, 0.00000000), controlPoint2: bottomLeft(0.86840701, 0.00000000))
		path.line(to: bottomLeft(0.63149399, 0.07491111))
		path.curve(to: bottomLeft(0.07491100, 0.63149399), controlPoint1: bottomLeft(0.37282401, 0.16905883), controlPoint2: bottomLeft(0.16906001, 0.37282392))
		path.curve(to: bottomLeft(0.00000000, 1.52866471), controlPoint1: bottomLeft(0.00000000, 0.86840689), controlPoint2: bottomLeft(0.00000000, 1.08849323))
		path.line(to: topLeft(0.00000000, 1.52866483))
		path.curve(to: topLeft(0.06549600, 0.66993397), controlPoint1: topLeft(0.00000000, 1.08849299), controlPoint2: topLeft(0.00000000, 0.86840701))
		path.line(to: topLeft(0.07491100, 0.63149399))
		path.curve(to: topLeft(0.63149399, 0.07491100), controlPoint1: topLeft(0.16906001, 0.37282401), controlPoint2: topLeft(0.37282401, 0.16906001))
		path.curve(to: topLeft(1.52866483, 0.00000000), controlPoint1: topLeft(0.86840701, 0.00000000), controlPoint2: topLeft(1.08849299, 0.00000000))
		path.close()
		return path
	}
}

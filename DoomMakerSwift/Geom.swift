/*
 DoomMaker
 Copyright (C) 2017  Ioan Chera

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation

/// PI representation
let π = M_PI
let πf = Float(M_PI)

class Geom {

    /// Checks if a line clips a rectangle, using Cohen-Sutherland's algorithm
    /// https://en.wikipedia.org/wiki/Cohen%E2%80%93Sutherland_algorithm
    static func lineClipsRect(_ pp0: NSPoint, _ pp1: NSPoint, rect: NSRect) -> Bool {

        let inside = 0
        let left = 1
        let right = 2
        let bottom = 4
        let top = 8

        func computeOutCode(_ p: NSPoint) -> Int {
            var code = inside
            if p.x < rect.minX {
                code |= left
            } else if p.x > rect.maxX {
                code |= right
            }
            if p.y < rect.minY {
                code |= bottom
            } else if p.y > rect.maxY {
                code |= top
            }
            return code
        }

        var p0 = pp0
        var p1 = pp1

        var outcode0 = computeOutCode(p0)
        var outcode1 = computeOutCode(p1)

        while true {
            if (outcode0 | outcode1) == 0 {
                return true
            }
            if (outcode0 & outcode1) != 0 {
                return false
            }
            let outcodeOut = outcode0 != 0 ? outcode0 : outcode1
            let p: NSPoint
            if (outcodeOut & top) != 0 {
                p = NSPoint(x: p0.x + (p1.x - p0.x) * (rect.maxY - p0.y) / (p1.y - p0.y), y: rect.maxY)
            } else if (outcodeOut & bottom) != 0 {
                p = NSPoint(x: p0.x + (p1.x - p0.x) * (rect.minY - p0.y) / (p1.y - p0.y), y: rect.minY)
            } else if (outcodeOut & right) != 0 {
                p = NSPoint(x: rect.maxX, y: p0.y + (p1.y - p0.y) * (rect.maxX - p0.x) / (p1.x - p0.x))
            } else if (outcodeOut & left) != 0 {
                p = NSPoint(x: rect.minX, y: p0.y + (p1.y - p0.y) * (rect.minX - p0.x) / (p1.x - p0.x))
            } else {
                assert(false)   // should never happen
                p = NSPoint()
            }

            if outcodeOut == outcode0 {
                p0 = p
                outcode0 = computeOutCode(p0)
            } else {
                p1 = p
                outcode1 = computeOutCode(p1)
            }
        }
    }
}

/// NSPoint addition
func + (left: NSPoint, right: NSPoint) -> NSPoint {
    return NSPoint(x: left.x + right.x, y: left.y + right.y)
}

/// NSPoint-NSSize addition
func + (left: NSPoint, right: NSSize) -> NSPoint {
    return NSPoint(x: left.x + right.width, y: left.y + right.height)
}

/// NSPoint subtraction
func - (left: NSPoint, right: NSPoint) -> NSPoint {
    return NSPoint(x: left.x - right.x, y: left.y - right.y)
}

/// NSPoint-NSSize subtraction
func - (left: NSPoint, right: NSSize) -> NSPoint {
    return NSPoint(x: left.x - right.width, y: left.y - right.height)
}

/// NSPoint-CGFloat division
func / (left: NSPoint, right: CGFloat) -> NSPoint {
    return NSPoint(x: left.x / right, y: left.y / right)
}

/// NSPoint-Double division
func / (left: NSPoint, right: Double) -> NSPoint {
    return left / CGFloat(right)
}

/// NSPoint-CGFloat multiplication
func * (left: NSPoint, right: CGFloat) -> NSPoint {
    return NSPoint(x: left.x * right, y: left.y * right)
}

/// NSPoint-Double multiplication
func * (left: NSPoint, right: Double) -> NSPoint {
    return left * CGFloat(right)
}

/// floor applied to NSPoint elements
func floor(_ point: NSPoint) -> NSPoint {
    return NSPoint(x: floor(point.x), y: floor(point.y))
}

/// ceil applied to NSPoint elements
func ceil(_ point: NSPoint) -> NSPoint {
    return NSPoint(x: ceil(point.x), y: ceil(point.y))
}

/// Distance operator
infix operator <-> : MultiplicationPrecedence

/// Additions to the NSPoint structure
extension NSPoint {

    /// Applies rotation to the 2D NSPoint vector
    func rotated(_ degrees: Float) -> NSPoint {
        let rad = degrees / 180 * πf
        let nx = Float(x) * cos(rad) - Float(y) * sin(rad)
        let ny = Float(x) * sin(rad) + Float(y) * cos(rad)
        return NSPoint(x: CGFloat(nx), y: CGFloat(ny))
    }

    init(vertex: Vertex) {
        self.init(x: Int(vertex.x), y: Int(vertex.y))
    }

    init(x: Int16, y: Int16) {
        self.init(x: Int(x), y: Int(y))
    }

    static func <-> (left: NSPoint, right: NSPoint) -> CGFloat {
        return sqrt(pow(left.x - right.x, 2) + pow(left.y - right.y, 2))
    }
}

/// NSRect additions
extension NSRect {

    /// Modifies this NSRect by adding the point to this as to a bounding box
    mutating func pointAdd(_ point: NSPoint) {
        if point.x > self.maxX {
            self.size.width = point.x - self.minX
        } else if point.x < self.minX {
            self.size.width = self.maxX - point.x
            self.origin.x = point.x
        }
        if point.y > self.maxY {
            self.size.height = point.y - self.minY
        } else if point.y < self.minY {
            self.size.height = self.maxY - point.y
            self.origin.y = point.y
        }
    }
}

/// Used to wrap a structure type into an class, useful for NSMapTable and
/// NSHashTable
class ObjWrap<T> {
    var data: T

    init(_ data: T) {
        self.data = data
    }
}

infix operator /• : MultiplicationPrecedence

func /• (left: CGFloat, right: CGFloat) -> CGFloat {
    return round(left / right) * right
}

func /• (left: NSPoint, right: CGFloat) -> NSPoint {
    return NSPoint(x: left.x /• right, y: left.y /• right)
}

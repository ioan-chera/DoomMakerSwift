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
let π = Double.pi
let πf = Float.pi

enum Geom {

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

    ///
    /// Finds projection of point
    ///
    static func projection(point: NSPoint, linep1: NSPoint, linep2: NSPoint) -> NSPoint
    {
        let x = point.x
        let y = point.y
        let x1 = linep1.x
        let y1 = linep1.y
        let dx = linep2.x - x1
        let dy = linep2.y - y1
        let dxsq = dx * dx
        let dysq = dy * dy
        let deltax = -x * dxsq - x1 * dysq + (y1 - y) * dx * dy
        let deltay = -y * dysq - y1 * dxsq + (x1 - x) * dy * dx
        let delta = -dxsq - dysq
        if delta != 0 {
            return NSPoint(x: deltax / delta, y: deltay / delta)
        }
        return linep1   // if not possible, just return one point
    }

    ///
    /// Find intersection point
    ///
    static func intersection(p00: NSPoint, p01: NSPoint, p10: NSPoint, p11: NSPoint) -> NSPoint? {
        let divisor = (p00.x - p01.x) * (p10.y - p11.y) - (p00.y - p01.y) * (p10.x - p11.x)
        if divisor == 0 {
            return nil
        }
        let fact1 = p00.x * p01.y - p00.y * p01.x
        let fact2 = p10.x * p11.y - p10.y * p11.x
        let d1 = fact1 * (p10.x - p11.x) - (p00.x - p01.x) * fact2
        let d2 = fact1 * (p10.y - p11.y) - (p00.y - p01.y) * fact2
        return NSPoint(x: d1 / divisor, y: d2 / divisor)
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

func * (left: NSPoint, right: NSPoint) -> CGFloat {
    return left.x * right.x + left.y * right.y
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

    init(item: DraggedItem) {
        self.init(x: Int(item.x), y: Int(item.y))
    }

    init(x: Int16, y: Int16) {
        self.init(x: Int(x), y: Int(y))
    }

    static func <-> (left: NSPoint, right: NSPoint) -> CGFloat {
        return sqrt(pow(left.x - right.x, 2) + pow(left.y - right.y, 2))
    }

    func distanceToLine(point1 p1: NSPoint, point2 p2: NSPoint) -> CGFloat {
        // https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line#Cartesian_coordinates
        return abs((p2.y - p1.y) * x - (p2.x - p1.x) * y + p2.x * p1.y - p2.y * p1.x) / (p1 <-> p2)
    }

    func distanceToSegment(point1 p1: NSPoint, point2 p2: NSPoint) -> CGFloat {
        if (p1 - self) * (p2 - p1) >= 0 {
            return self <-> p1
        }
        if (self - p2) * (p2 - p1) >= 0 {
            return self <-> p2
        }
        return distanceToLine(point1: p1, point2: p2)
    }

    func withinRoundedRect(_ rect: NSRect, radius: CGFloat) -> Bool {
        if x >= rect.minX && x < rect.maxX &&
            y >= rect.minY - radius && y < rect.maxY + radius
        {
            return true
        }
        if x < rect.minX && x >= rect.minX - radius {
            if y >= rect.minY && y < rect.maxY {
                return true
            }
            if y >= rect.minY - radius && y < rect.minY {
                return self <-> NSPoint(x: rect.minX, y: rect.minY) <= radius
            }
            if y >= rect.maxY && y < rect.maxY + radius {
                return self <-> NSPoint(x: rect.minX, y: rect.maxY) <= radius
            }
            return false
        }
        if x >= rect.maxX && x < rect.maxX + radius {
            if y >= rect.minY && y < rect.maxY {
                return true
            }
            if y >= rect.minY - radius && y < rect.minY {
                return self <-> NSPoint(x: rect.maxX, y: rect.minY) <= radius
            }
            if y >= rect.maxY && y < rect.maxY + radius {
                return self <-> NSPoint(x: rect.maxX, y: rect.maxY) <= radius
            }
            return false
        }
        return false
    }

    /// Cross product's Z
    func drill(_ point: NSPoint) -> CGFloat {
        return x * point.y - point.x * y
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

    init(point1: NSPoint, point2: NSPoint) {
        self.init()
        self.origin = point1
        self.size = NSSize()
        pointAdd(point2)
    }
}

infix operator /• : MultiplicationPrecedence

func /• (left: CGFloat, right: CGFloat) -> CGFloat {
    return round(left / right) * right
}
func /• (left: Float, right: Float) -> Float {
    return round(left / right) * right
}
func /• (left: NSPoint, right: CGFloat) -> NSPoint {
    return NSPoint(x: left.x /• right, y: left.y /• right)
}

//
// For line relative position
//
enum Side {
    case front
    case back
    init(_ value: Int) {
        self = value == 0 ? .front : .back
    }
    init(_ value: Bool) {
        self = value ? .back : .front
    }
}

prefix func ! (right: Side) -> Side {
    return right == .front ? .back : .front
}

func anglemod(_ angle: Double) -> Double {
    var res = angle
    while res < -π {
        res += 2 * π
    }
    while res >= π {
        res -= 2 * π
    }
    return res
}

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

let π = M_PI
let πf = Float(M_PI)

class Geom {

    // https://en.wikipedia.org/wiki/Cohen%E2%80%93Sutherland_algorithm
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

func + (left: NSPoint, right: NSPoint) -> NSPoint {
    return NSPoint(x: left.x + right.x, y: left.y + right.y)
}

func + (left: NSPoint, right: NSSize) -> NSPoint {
    return NSPoint(x: left.x + right.width, y: left.y + right.height)
}

func - (left: NSPoint, right: NSPoint) -> NSPoint {
    return NSPoint(x: left.x - right.x, y: left.y - right.y)
}

func - (left: NSPoint, right: NSSize) -> NSPoint {
    return NSPoint(x: left.x - right.width, y: left.y - right.height)
}

func / (left: NSPoint, right: CGFloat) -> NSPoint {
    return NSPoint(x: left.x / right, y: left.y / right)
}

func / (left: NSPoint, right: Double) -> NSPoint {
    return left / CGFloat(right)
}

func * (left: NSPoint, right: CGFloat) -> NSPoint {
    return NSPoint(x: left.x * right, y: left.y * right)
}

func * (left: NSPoint, right: Double) -> NSPoint {
    return left * CGFloat(right)
}

func floor(_ point: NSPoint) -> NSPoint {
    return NSPoint(x: floor(point.x), y: floor(point.y))
}

func ceil(_ point: NSPoint) -> NSPoint {
    return NSPoint(x: ceil(point.x), y: ceil(point.y))
}

extension NSPoint {
    func rotated(_ degrees: Float) -> NSPoint {
        let rad = degrees / 180 * πf
        let nx = Float(x) * cos(rad) - Float(y) * sin(rad)
        let ny = Float(x) * sin(rad) + Float(y) * cos(rad)
        return NSPoint(x: CGFloat(nx), y: CGFloat(ny))
    }
    func distance(point: NSPoint) -> CGFloat {
        return sqrt(pow(point.x - self.x, 2) + pow(point.y - self.y, 2))
    }
}

extension NSRect {
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


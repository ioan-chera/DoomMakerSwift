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

/// Linedef flags. FIXME: vanilla for now.
enum LineFlag {
    static let impassable = 1
    static let twoSided = 4
    static let upperUnpeg = 8
    static let lowerUnpeg = 16
    
}

/// This is the structure needed for linedefs to load and save file. Separate
/// from Linedef because of non-nullable constraints
struct LinedefData: Serializable {

    let v1idx: Int16
    let v2idx: Int16
    let flags: Int16
    let special: Int16
    let tag: Int16
    let s1idx: Int16
    let s2idx: Int16

    init(data: [UInt8]) {
        let reader = DataReader(data)
        v1idx = reader.short()
        v2idx = reader.short()
        flags = reader.short()
        special = reader.short()
        tag = reader.short()
        s1idx = reader.short()
        s2idx = reader.short()
    }

    init(linedef: Linedef, vertices: [Vertex], sidedefs: [Sidedef]) throws {
        v1idx = try Int16(throwing: vertices.index(of: linedef.v1) ?? -1)
        v2idx = try Int16(throwing: vertices.index(of: linedef.v2) ?? -1)
        flags = try Int16(throwing: linedef.flags)
        special = try Int16(throwing: linedef.special)
        tag = try Int16(throwing: linedef.tag)
        if let s1 = linedef.s1 {
            s1idx = try Int16(throwing: sidedefs.index(of: s1) ?? -1)
        } else {
            s1idx = -1
        }
        if let s2 = linedef.s2 {
            s2idx = try Int16(throwing: sidedefs.index(of: s2) ?? -1)
        } else {
            s2idx = -1
        }
    }

    var serialized: [UInt8] {
        return DataWriter([]).short(v1idx).short(v2idx).short(flags)
            .short(special).short(tag).short(s1idx).short(s2idx).data
    }
}

/// Map linedef
final class Linedef: InteractiveItem {
    var flags: Int   // linedef bits
    var special: Int // linedef trigger special
    var tag: Int     // linedef trigger tag

    var v1: Vertex {
        willSet(newValue) {
            v1.removeLine(self)
        }
        didSet {
            v1.addLine(self)
        }
    }

    var v2: Vertex {
        willSet(newValue) {
            v2.removeLine(self)
        }
        didSet {
            v2.addLine(self)
        }
    }

    weak var s1: Sidedef? = nil {
        willSet(newValue) {
            s1?.removeLine(self)
        }
        didSet {
            s1?.addLine(self)
        }
    }

    weak var s2: Sidedef? = nil {
        willSet(newValue) {
            s2?.removeLine(self)
        }
        didSet {
            s2?.addLine(self)
        }
    }

    subscript(side: Side) -> Sidedef? {
        get {
            return side == .front ? s1 : s2
        }
        set(value) {
            if side == .front {
                s1 = value
            } else {
                s2 = value
            }
        }
    }

    init?(data: LinedefData, vertices: [Vertex], sidedefs: [Sidedef]) {
        if !Int(data.v1idx).inRange(min: 0, max: vertices.count - 1) ||
            !Int(data.v2idx).inRange(min: 0, max: vertices.count - 1)
        {
            return nil
        }
        flags = Int(data.flags)
        special = Int(data.special)
        tag = Int(data.tag)
        v1 = vertices[Int(data.v1idx)]
        v2 = vertices[Int(data.v2idx)]
        s1 = sidedefs.safeAt(Int(data.s1idx))
        s2 = sidedefs.safeAt(Int(data.s2idx))
        super.init()
        v1.addLine(self)
        v2.addLine(self)
        s1?.addLine(self)
        s2?.addLine(self)
    }

    var frontsector: Sector? {
        get {
            return s1?.sector
        }
    }
    var backsector: Sector? {
        get {
            return s2?.sector
        }
    }

    func length() -> Double {
        return sqrt(pow(Double(v1.x) - Double(v2.x), 2) +
            pow(Double(v1.y) - Double(v2.y), 2))
    }

    //==========================================================================
    //
    // MARK: InteractiveItem
    //

    override var draggables: Set<DraggedItem> {
        return [v1, v2]
    }

    override var linedefs: Set<Linedef> {
        return [self]
    }

    override var sectors: Set<Sector> {
        var result = Set<Sector>()
        if let sector = s1?.sector {
            result.insert(sector)
        }
        if let sector = s2?.sector {
            result.insert(sector)
        }
        return result
    }

    //==========================================================================
    //
    // MARK: utilities
    //

    ///
    /// Like Doom's P_PointOnLineSide
    ///
    func lineSide(point: NSPoint) -> Side {
        let dx = Int(v2.x) - Int(v1.x)
        let dy = Int(v2.y) - Int(v1.y)
        if dx == 0 {
            if point.x <= CGFloat(v1.x) {
                return Side(dy > 0)
            }
            return Side(dy < 0)
        }
        if dy == 0 {
            if point.y <= CGFloat(v1.y) {
                return Side(dx < 0)
            }
            return Side(dx > 0)
        }
        return Side((point.y - CGFloat(v1.y)) * CGFloat(dx) >=
            CGFloat(dy) * (point.x - CGFloat(v1.x)))
    }
}

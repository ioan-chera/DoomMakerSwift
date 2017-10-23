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

let LineFlagImpassable = 1
let LineFlagTwoSided = 4

/// This is the structure needed for linedefs to load and save file. Separate
/// from Linedef because of non-nullable constraints
struct LinedefData: Serializable {

    private(set) var v1idx = 0
    private(set) var v2idx = 0
    private(set) var flags = 0
    private(set) var special = 0
    private(set) var tag = 0
    private(set) var s1idx = -1
    private(set) var s2idx = -1

    init(data: [UInt8]) {
        DataReader(data).short(&v1idx).short(&v2idx).short(&flags).short(&special)
            .short(&tag).short(&s1idx).short(&s2idx)
    }

    init(linedef: Linedef, vertices: [Vertex], sidedefs: [Sidedef]) {
        v1idx = vertices.index(of: linedef.v1) ?? -1
        v2idx = vertices.index(of: linedef.v2) ?? -1
        flags = linedef.flags
        special = linedef.special
        tag = linedef.tag
        if let s1 = linedef.s1 {
            s1idx = sidedefs.index(of: s1) ?? -1
        }
        if let s2 = linedef.s2 {
            s2idx = sidedefs.index(of: s2) ?? -1
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

    init?(data: LinedefData, vertices: [Vertex], sidedefs: [Sidedef]) {
        if !data.v1idx.inRange(min: 0, max: vertices.count - 1) ||
            !data.v2idx.inRange(min: 0, max: vertices.count - 1)
        {
            return nil
        }
        flags = data.flags
        special = data.special
        tag = data.tag
        v1 = vertices[data.v1idx]
        v2 = vertices[data.v2idx]
        s1 = sidedefs.safeAt(data.s1idx)
        s2 = sidedefs.safeAt(data.s2idx)
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
}

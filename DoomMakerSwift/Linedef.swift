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

/// Map linedef
final class Linedef: IndividualItem, MapItem {
    private(set) var v1idx = 0      // vertex index
    private(set) var v2idx = 0      // vertex index
    var flags = 0   // linedef bits
    var special = 0 // linedef trigger special
    var tag = 0     // linedef trigger tag
    private(set) var s1idx = -1      // side index
    private(set) var s2idx = -1      // side index

    weak var v1: Vertex? = nil {
        willSet(newValue) {
            v1?.removeLine(self)
        }
        didSet {
            v1?.addLine(self)
        }
    }

    weak var v2: Vertex? = nil {
        willSet(newValue) {
            v2?.removeLine(self)
        }
        didSet {
            v2?.addLine(self)
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

    init(data: [UInt8]) {
        DataReader(data).short(&v1idx).short(&v2idx).short(&flags).short(&special)
            .short(&tag).short(&s1idx).short(&s2idx)
    }

    func getData() -> [UInt8] {
        return DataWriter([]).short(v1idx).short(v2idx).short(flags)
            .short(special).short(tag).short(s1idx).short(s2idx).data
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
    var vertices: [Vertex] {
        get {
            var ret: [Vertex] = []
            if let v1 = self.v1 {
                ret.append(v1)
            }
            if let v2 = self.v2 {
                ret.append(v2)
            }
            return ret
        }
    }

    func length() -> Double {
        guard let v1 = self.v1 else {
            return 0
        }
        guard let v2 = self.v2 else {
            return 0
        }
        return sqrt(pow(Double(v1.x) - Double(v2.x), 2) +
            pow(Double(v1.y) - Double(v2.y), 2))
    }

    ///
    /// Updates the vertex indices to be in sync with array
    ///
    func fixIndices(vertices: [Vertex], sidedefs: [Sidedef]) {
        v1idx = indexOf(array: vertices, item: v1) ?? -1
        v2idx = indexOf(array: vertices, item: v2) ?? -1
        s1idx = indexOf(array: sidedefs, item: s1) ?? -1
        s2idx = indexOf(array: sidedefs, item: s2) ?? -1
    }
}

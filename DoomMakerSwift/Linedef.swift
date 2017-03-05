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

/// Map linedef
final class Linedef: MapItem {
    private(set) var v1idx = 0      // vertex index
    private(set) var v2idx = 0      // vertex index
    var flags = 0   // linedef bits
    var special = 0 // linedef trigger special
    var tag = 0     // linedef trigger tag
    private(set) var s1idx = -1      // side index
    private(set) var s2idx = -1      // side index

    private(set) weak var v1: Vertex? = nil
    private(set) weak var v2: Vertex? = nil
    private(set) weak var s1: Sidedef? = nil
    private(set) weak var s2: Sidedef? = nil

    init(data: [UInt8]) {
        DataReader(data).short(&v1idx).short(&v2idx).short(&flags).short(&special)
            .short(&tag).short(&s1idx).short(&s2idx)
    }

    func getData() -> [UInt8] {
        return DataWriter([]).short(v1idx).short(v2idx).short(flags)
            .short(special).short(tag).short(s1idx).short(s2idx).data
    }

    func setV1(list: [Vertex], index: Int) {
        v1idx = index
        safeArraySet(&v1, list: list, index: index)
    }

    func setV2(list: [Vertex], index: Int) {
        v2idx = index
        safeArraySet(&v2, list: list, index: index)
    }

    func setS1(list: [Sidedef], index: Int) {
        s1idx = index
        safeArraySet(&s1, list: list, index: index)
    }

    func setS2(list: [Sidedef], index: Int) {
        s2idx = index
        safeArraySet(&s2, list: list, index: index)
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
}

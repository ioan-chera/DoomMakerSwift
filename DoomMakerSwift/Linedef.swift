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
    var s1 = 0      // side index
    var s2 = 0      // side index

    private(set) weak var v1: Vertex? = nil
    private(set) weak var v2: Vertex? = nil

    init(data: [UInt8]) {
        DataReader(data).short(&v1idx).short(&v2idx).short(&flags).short(&special)
            .short(&tag).short(&s1).short(&s2)
    }

    func getData() -> [UInt8] {
        return DataWriter([]).short(v1idx).short(v2idx).short(flags)
            .short(special).short(tag).short(s1).short(s2).data
    }

    func setV1(list: [Vertex], index: Int) {
        v1idx = index
        if index >= 0 && index < list.count {
            v1 = list[index]
        }
    }

    func setV2(list: [Vertex], index: Int) {
        v2idx = index
        if index >= 0 && index < list.count {
            v2 = list[index]
        }
    }
}

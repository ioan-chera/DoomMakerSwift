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

/// Map sector
final class Sector: InteractiveItem, Serializable {
    var floorheight = 0         // floor height
    var ceilingheight = 0       // ceiling height
    var floor: [UInt8] = []     // floor
    var ceiling: [UInt8] = []   // ceiling
    var light = 0               // light level
    var special = 0             // sector special
    var tag = 0                 // sector trigger tag

    private(set) var sidedefs = Set<Sidedef>()

    init(data: [UInt8]) {
        DataReader(data).short(&floorheight).short(&ceilingheight)
            .lumpName(&floor).lumpName(&ceiling).short(&light)
            .short(&special).short(&tag)
    }

    var serialized: [UInt8] {
        return DataWriter().short(floorheight).short(ceilingheight)
            .lumpName(floor).lumpName(ceiling).short(light).short(special)
            .short(tag).data
    }

    func addSide(_ side: Sidedef) {
        sidedefs.insert(side)
    }

    func removeSide(_ side: Sidedef) {
        sidedefs.remove(side)
    }

    //==========================================================================
    //
    // MARK: VertexContainer
    //

    ///
    /// Obtains vertices from sidedefs
    ///
    override var draggables: Set<DraggedItem> {
        var result = Set<DraggedItem>()

        for side in sidedefs {
            for line in side.linedefs {
                result.formUnion([line.v1, line.v2])
            }
        }

        return result
    }

    ///
    /// Obtains linedefs from sidedefs
    ///
    override var linedefs: Set<Linedef> {
        var result = Set<Linedef>()

        for side in sidedefs {
            for line in side.linedefs {
                result.insert(line)
            }
        }

        return result
    }

    override var sectors: Set<Sector> {
        return Set([self])
    }
}

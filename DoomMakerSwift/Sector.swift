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
final class Sector: MapItem {
    var floorheight = 0         // floor height
    var ceilingheight = 0       // ceiling height
    var floor: [UInt8] = []     // floor
    var ceiling: [UInt8] = []   // ceiling
    var light = 0               // light level
    var special = 0             // sector special
    var tag = 0                 // sector trigger tag

    private let sidedefs: NSHashTable<Sidedef> = NSHashTable.weakObjects()

    init(data: [UInt8]) {
        DataReader(data).short(&floorheight).short(&ceilingheight)
            .lumpName(&floor).lumpName(&ceiling).short(&light)
            .short(&special).short(&tag)
    }

    func getData() -> [UInt8] {
        return DataWriter().short(floorheight).short(ceilingheight)
            .lumpName(floor).lumpName(ceiling).short(light).short(special)
            .short(tag).data
    }

    func addSide(_ side: Sidedef) {
        sidedefs.add(side)
    }

    func removeSide(_ side: Sidedef) {
        sidedefs.remove(side)
    }

    ///
    /// Obtains vertices from sidedefs
    ///
    func obtainVertices() -> NSHashTable<Vertex> {
        let sideEnum = sidedefs.objectEnumerator()
        let result = NSHashTable<Vertex>.weakObjects()
        while let side = sideEnum.nextObject() as? Sidedef {
            let lineEnum = side.lineEnumerator
            while let line = lineEnum.nextObject() as? Linedef {
                result.add(line.v1)
                result.add(line.v2)
            }
        }
        return result
    }

    ///
    /// Obtains linedefs from sidedefs
    ///
    func obtainLinedefs() -> NSHashTable<Linedef> {
        let sideEnum = sidedefs.objectEnumerator()
        let result = NSHashTable<Linedef>.weakObjects()
        while let side = sideEnum.nextObject() as? Sidedef {
            let lineEnum = side.lineEnumerator
            while let line = lineEnum.nextObject() as? Linedef {
                result.add(line)
            }
        }
        return result
    }
}

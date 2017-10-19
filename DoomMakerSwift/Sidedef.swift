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

/// Map sidedef
final class Sidedef: MapItem {
    var xOffset = 0             // x offset
    var yOffset = 0             // y offset
    var upper: [UInt8] = []     // upper texture
    var lower: [UInt8] = []     // lower texture
    var middle: [UInt8] = []    // middle texture
    private(set) var secnum = -1    // sector reference. NEEDS to be updated.

    weak var sector: Sector? {
        willSet(newValue) {
            sector?.removeSide(self)
        }
        didSet {
            sector?.addSide(self)
        }
    }

    let linedefs = NSHashTable<Linedef>.weakObjects()

    init(data: [UInt8]) {
        DataReader(data).short(&xOffset).short(&yOffset).lumpName(&upper)
            .lumpName(&lower).lumpName(&middle).short(&secnum)
    }

    func getData() -> [UInt8] {
        return DataWriter().short(xOffset).short(yOffset).lumpName(upper)
            .lumpName(lower).lumpName(middle).short(secnum).data
    }

    func addLine(_ line: Linedef) {
        linedefs.add(line)
    }

    func removeLine(_ line: Linedef) {
        linedefs.remove(line)
    }

    var lineEnumerator: NSEnumerator {
        get {
            return linedefs.objectEnumerator()
        }
    }
}

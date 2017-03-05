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
    var sector = 0              // sector reference

    init(data: [UInt8]) {
        DataReader(data).short(&xOffset).short(&yOffset).lumpName(&upper)
            .lumpName(&lower).lumpName(&middle).short(&sector)
    }

    func getData() -> [UInt8] {
        return DataWriter().short(xOffset).short(yOffset).lumpName(upper)
            .lumpName(lower).lumpName(middle).short(sector).data
    }
}

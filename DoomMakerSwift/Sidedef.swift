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

struct SidedefData: Serializable {
    let xOffset: Int16
    let yOffset: Int16
    let upper: [UInt8]
    let lower: [UInt8]
    let middle: [UInt8]
    let secnum: Int16

    init(data: [UInt8]) {
        let reader = DataReader(data)
        xOffset = reader.short()
        yOffset = reader.short()
        upper = reader.lumpName()
        lower = reader.lumpName()
        middle = reader.lumpName()
        secnum = reader.short()
    }

    init(sidedef: Sidedef, sectors: [Sector]) throws {
        xOffset = try Int16(throwing: sidedef.xOffset)
        yOffset = try Int16(throwing: sidedef.yOffset)
        upper = sidedef.upper.data
        lower = sidedef.lower.data
        middle = sidedef.middle.data
        secnum = try Int16(throwing: sectors.firstIndex(of: sidedef.sector) ?? -1)
    }

    var serialized: [UInt8] {
        return DataWriter().short(xOffset).short(yOffset).lumpName(upper)
            .lumpName(lower).lumpName(middle).short(secnum).data
    }
}

///
/// Map sidedef.
///
final class Sidedef: IndividualItem {
    var xOffset: Int             // x offset
    var yOffset: Int             // y offset
    var upper: TextureName
    var lower: TextureName
    var middle: TextureName

    var sector: Sector {
        willSet(newValue) {
            sector.removeSide(self)
        }
        didSet {
            sector.addSide(self)
        }
    }

    private(set) var linedefs = Set<Linedef>()

    init?(data: SidedefData, sectors: [Sector]) {
        if !Int(data.secnum).inRange(min: 0, max: sectors.count - 1) {
            return nil
        }
        xOffset = Int(data.xOffset)
        yOffset = Int(data.yOffset)
        upper = TextureName(bytes: data.upper)
        lower = TextureName(bytes: data.lower)
        middle = TextureName(bytes: data.middle)
        sector = sectors[Int(data.secnum)]
        super.init()
        sector.addSide(self)
    }

    init(from sidedef: Sidedef) {
        xOffset = sidedef.xOffset
        yOffset = sidedef.yOffset
        upper = sidedef.upper
        lower = sidedef.lower
        middle = sidedef.middle
        self.sector = sidedef.sector
        super.init()
        sector.addSide(self)
    }

    func addLine(_ line: Linedef) {
        linedefs.insert(line)
    }

    func removeLine(_ line: Linedef) {
        linedefs.remove(line)
    }
}

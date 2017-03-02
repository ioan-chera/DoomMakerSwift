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

final class Vertex: MapItem {
    var x, y: Int16

    private(set) var dragging = false
    private var dragX: Int16 = 0, dragY: Int16 = 0

    var apparentX: Int16 {
        get {
            return dragging ? dragX : x
        }
    }

    var apparentY: Int16 {
        get {
            return dragging ? dragY : y
        }
    }

    init(x: Int16, y: Int16) {
        self.x = x
        self.y = y
    }
    init(data: [UInt8]) {
        x = 0
        y = 0
        DataReader(data).short(&x).short(&y)
    }

    func getData() -> [UInt8] {
        return DataWriter([]).short(x).short(y).data
    }

    func setDragging(x: Int16, y: Int16) -> Bool {
        // Don't turn on dragging if it was off and no movement took place
        dragging = dragging || x != self.x || y != self.y
        dragX = x
        dragY = y
        return dragging
    }

    func setDragging(point: NSPoint) -> Bool {
        return setDragging(x: Int16(round(point.x)), y: Int16(round(point.y)))
    }

    func endDragging() {
        dragging = false
    }
}

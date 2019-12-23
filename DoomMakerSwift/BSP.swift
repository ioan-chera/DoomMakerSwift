/*
DoomMaker
Copyright (C) 2019  Ioan Chera

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

/// BSP segment
final class Seg: Serializable {
    var v1 = 0      // vertex one
    var v2 = 0      // vertex two
    var angle = 0   // direction angle (unused?)
    var line = 0    // source linedef
    var dir = 0     // whether it's in the same direction or not
    var offset = 0  // offset along linedef

    init(data: [UInt8]) {
        DataReader(data).short(&v1).short(&v2).short(&angle).short(&line)
            .short(&dir).short(&offset)
    }

    var serialized: [UInt8] {
        return DataWriter().short(v1).short(v2).short(angle).short(line)
            .short(dir).short(offset).data
    }
}

/// BSP subsector
final class Subsector: Serializable {
    var segCount = 0    // number of segs
    var firstSeg = 0    // first seg

    init(data: [UInt8]) {
        DataReader(data).short(&segCount).short(&firstSeg)
    }

    var serialized: [UInt8] {
        return DataWriter().short(segCount).short(firstSeg).data
    }
}

/// BSP split
final class Node: Serializable {
    var x0 = 0  // split start position
    var y0 = 0  // split start position
    var dx = 0  // split move to end
    var dy = 0  // split move to end
    var rightBox = (top:0, bottom:0, left:0, right:0)   // right bounding box
    var leftBox = (top:0, bottom:0, left:0, right:0)    // left bounding box
    var rightChild = 0  // right node or subsector
    var leftChild = 0   // left node or subsector

    init(data: [UInt8]) {
        DataReader(data).short(&x0).short(&y0).short(&dx).short(&dy)
            .short(&rightBox.top).short(&rightBox.bottom)
            .short(&rightBox.left).short(&rightBox.right)
            .short(&leftBox.top).short(&leftBox.bottom).short(&leftBox.left)
            .short(&leftBox.right)
            .short(&rightChild).short(&leftChild)
    }

    var serialized: [UInt8] {
        return DataWriter().short(x0).short(y0).short(dx).short(dy)
            .short(rightBox.top).short(rightBox.bottom).short(rightBox.left)
            .short(rightBox.right).short(leftBox.top).short(leftBox.bottom)
            .short(leftBox.left).short(leftBox.right).short(rightChild)
            .short(leftChild).data
    }
}

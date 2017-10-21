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

/**
 Quick way to read data from a stream into useful variables.
 */
class DataReader {
    private let data: [UInt8]
    private var pos = 0

    /**
     Initializes with an UInt8 array/
    */
    init(_ data: [UInt8]) {
        self.data = data
    }

    /**
     Reads a 16-bit value
 */
    @discardableResult
    func short(_ val: inout Int) -> DataReader {
        val = Int(Int16(data[pos]) + (Int16(data[pos + 1]) << 8))
        pos += 2
        return self
    }

    @discardableResult
    func short(_ val: inout Int16) -> DataReader {
        val = Int16(data[pos]) | (Int16(data[pos + 1]) << 8)
        pos += 2
        return self
    }

    /**
    Reads a lump name
 */
    func lumpName(_ val: inout [UInt8]) -> DataReader {
        val = Lump.truncateZero(Array(data[pos ..< pos + 8]))
        val.append(0)   // ensure null terminator
        pos += 8
        return self
    }
}

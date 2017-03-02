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
 Quick way to write data from a stream into useful variables.
 */
class DataWriter {
    private(set) var data: [UInt8]
    private var pos = 0

    /**
     Initializes with an UInt8 array/
     */
    init(_ data: [UInt8]) {
        self.data = data
    }

    convenience init() {
        self.init([])
    }

    private func addByte(_ val: Int) {
        if pos == data.count {
            data.append(UInt8(val))
        } else {
            data[pos] = UInt8(val)
        }
        pos += 1
    }

    /**
     Reads a 16-bit value
     */
    @discardableResult
    func short(_ val: Int) -> DataWriter {
        addByte(val & 0xff)
        addByte(val >> 8 & 0xff)
        return self
    }

    @discardableResult
    func short(_ val: Int16) -> DataWriter {
        let ival = Int(val)
        addByte(ival & 0xff)
        addByte(ival >> 8 & 0xff)
        return self
    }

    @discardableResult
    func lumpName(_ val: [UInt8]) -> DataWriter {
        var count = 0
        for byte in val {
            addByte(Int(byte))
            count += 1
            if count == 8 {
                break
            }
        }
        while count < 8 {
            addByte(0)
            count += 1
        }
        return self
    }
}

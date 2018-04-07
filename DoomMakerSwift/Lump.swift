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

///
/// Wad lump. Contains the actual data and the name.
///
class Lump
{
    fileprivate var _nameBytes: [UInt8]  // byte array up to 8 values
    var data: [UInt8]

    var nameBytes: [UInt8] {
        get {
            return self._nameBytes
        }
        set(value) {
            self._nameBytes = Lump.truncateZero(value)
        }
    }

    var name: String {
        get {
            return Lump.nameAsString(self.nameBytes)
        }
        set(value) {
            var string = value.uppercased()
            if value.count > 8 {
                string = String(string[..<value.index(value.startIndex, offsetBy: 8)])
                while string.count > 1 && string.utf8.count > 8 {
                    string = String(string[..<string.index(before: string.endIndex)])
                }
            }
            self.nameBytes = Array(string.utf8)
        }
    }

    static func nameAsString(_ nameBytes: [UInt8]) -> String {
        let string = String(bytes: nameBytes, encoding: String.Encoding.utf8) ?? ""
        return string.uppercased()
    }

    static func truncateZero(_ bytes: [UInt8]) -> [UInt8] {
        var result: [UInt8] = []
        for a in bytes {
            if a == 0 {
                return result
            }
            result.append(a)   // preserve all values up to the
            // null terminator
        }
        return result
    }

    init(name: String)
    {
        self._nameBytes = []
        self.data = []
        self.name = name
    }

    init(name: String, data: Data)
    {
        self._nameBytes = []
        self.data = data.asArray()
        self.name = name
    }

    init(nameData: Data, data: Data) {
        self._nameBytes = []
        self.data = data.asArray()
        self.nameBytes = nameData.asArray()
    }
}

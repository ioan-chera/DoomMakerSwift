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
/// This holds the name of a texture, either in raw format or in string format
///
struct TextureName {
    let data: [UInt8]

    init(_ name: String = "-") {
        self.init(bytes: [UInt8](name.utf8))
    }

    init(bytes: [UInt8]) {
        var utf8 = bytes
        if utf8.count > 8 {
            utf8 = Array(utf8[0..<8])
        }
        data = utf8
    }

    var name: String {
//        get {
            let safeData = data + [UInt8(0)]
            return String(cString: safeData)
//        }
//        set(value) {
//            var utf8 = [UInt8](value.utf8)
//            if utf8.count > 8 {
//                utf8 = Array(utf8[0..<8])
//            }
//            data = utf8
//        }
    }
}

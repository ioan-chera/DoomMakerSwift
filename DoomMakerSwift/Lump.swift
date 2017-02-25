//
//  Lump.swift
//  DoomMakerSwift
//
//  Created by ioan on 13.07.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

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
            if value.characters.count > 8 {
                string = string.substring(to: value.characters.index(value.startIndex, offsetBy: 8))
                while string.characters.count > 1 && string.utf8.count > 8 {
                    string = string.substring(to: string.characters.index(before: string.endIndex))
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

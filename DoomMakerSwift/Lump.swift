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
    private var _nameBytes: [UInt8]  // byte array up to 8 values
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
            var string = value.uppercaseString
            if value.characters.count > 8 {
                string = string.substringToIndex(value.startIndex.advancedBy(8))
                while string.characters.count > 1 && string.utf8.count > 8 {
                    string = string.substringToIndex(string.endIndex.predecessor())
                }
            }
            self.nameBytes = Array(string.utf8)
        }
    }

    static func nameAsString(nameBytes: [UInt8]) -> String {
        let string = String(bytes: nameBytes, encoding: NSUTF8StringEncoding) ?? ""
        return string.uppercaseString
    }

    static func truncateZero(let bytes: [UInt8]) -> [UInt8] {
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

    init(name: String, data: NSData)
    {
        self._nameBytes = []
        self.data = data.asArray()
        self.name = name
    }

    init(nameData: NSData, data: NSData) {
        self._nameBytes = []
        self.data = data.asArray()
        self.nameBytes = nameData.asArray()
    }
}
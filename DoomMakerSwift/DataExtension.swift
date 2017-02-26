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

/*
 This file implements common data reading, writing and processing routines
 */

import Foundation

/**
 Reads a string, formatted as C null-terminated, into a String object.
 */
func cString(_ data: [UInt8], loc: Int, len: Int) -> String
{
    var ret = ""
    for u in data
    {
        if u == 0
        {
            break
        }
        ret.append(String(describing: UnicodeScalar(Int(u))))
    }
    return ret
}

/**
 Reads a 16-bit value into a Double variable.
 */
func doubleFromInt16(_ data: [UInt8], loc: Int) -> Double
{
    return Double(Int(Int8(bitPattern:data[loc])) + (Int(Int8(bitPattern:data[loc + 1])) << 8))
}

/**
 Reads a 16-bit value into an Int variable.
 */
func intFromInt16(_ data: [UInt8], loc: Int) -> Int
{
    return Int(Int8(bitPattern:data[loc])) + (Int(Int8(bitPattern:data[loc + 1])) << 8)
}

/**
 Gets a subarray (not just slice).
 */
func subArray<T>(_ array: [T], loc: Int, len: Int) -> [T]
{
    return Array(array[loc...loc + len - 1])
}

/**
 Same as the public cString function.
 */
private func cStringRaw(_ data: [UInt8], loc: Int, len: Int) -> String
{
    return cString(data, loc: loc, len: len)
}

/**
 Obtains a little-endian byte array from an Int32 variable
 */
func bytesFromInt32(_ num32: Int32) -> [UInt8] {
    let num = Int(num32)
    return [UInt8(num & 0xff), UInt8(num >> 8 & 0xff), UInt8(num >> 16 & 0xff), UInt8(num >> 24 & 0xff)]
}

/**
 Extensions to the Swift Data type
 */
extension Data
{
    /**
     Converts UTF8 data into a String value.
     */
    func string(_ loc: Int, len: Int) -> String
    {
        var raw = Array<UInt8>(repeating: 0, count: len)
        copyBytes(to: &raw, from: loc..<(loc + len))
        return NSString(bytes: raw, length: len, encoding: String.Encoding.utf8.rawValue)! as String
    }

    /**
     Reads a C string into a String value
     */
    func cString(_ loc: Int, len: Int) -> String
    {
        var raw = Array<UInt8>(repeating: 0, count: len)
        copyBytes(to: &raw, from: loc..<(loc + len))
        return cStringRaw(raw, loc: loc, len: len)
    }

    /**
     Reads a 32-bit integer.
     */
    func int32(_ loc: Int) -> Int32
    {
        var raw = Array<UInt8>(repeating: 0, count: 4)
        copyBytes(to: &raw, from: loc..<(loc + 4))
        var ret = Int32(raw[0])
        ret |= Int32(raw[1]) << 8
        ret |= Int32(raw[2]) << 16
        ret |= Int32(raw[3]) << 24
        return ret
    }

    /**
     Converts the Data to an UInt8 array.
     */
    func asArray() -> [UInt8] {
        var result = Array<UInt8>(repeating: 0, count: self.count)
        (self as NSData).getBytes(&result, length: self.count)
        return result
    }
}


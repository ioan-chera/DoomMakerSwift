//
//  DataExtension.swift
//  DoomMakerSwift
//
//  Created by ioan on 24.01.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Foundation

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

func doubleFromInt16(_ data: [UInt8], loc: Int) -> Double
{
    return Double(Int(Int8(bitPattern:data[loc])) + (Int(Int8(bitPattern:data[loc + 1])) << 8))
}

func intFromInt16(_ data: [UInt8], loc: Int) -> Int
{
    return Int(Int8(bitPattern:data[loc])) + (Int(Int8(bitPattern:data[loc + 1])) << 8)
}

func subArray<T>(_ array: [T], loc: Int, len: Int) -> [T]
{
    return Array(array[loc...loc + len - 1])
}

private func cStringRaw(_ data: [UInt8], loc: Int, len: Int) -> String
{
    return cString(data, loc: loc, len: len)
}

func bytesFromInt32(_ num32: Int32) -> [UInt8] {
    let num = Int(num32)
    return [UInt8(num & 0xff), UInt8(num >> 8 & 0xff), UInt8(num >> 16 & 0xff), UInt8(num >> 24 & 0xff)]
}

extension Data
{
    func string(_ loc: Int, len: Int) -> String
    {
        var raw = Array<UInt8>(repeating: 0, count: len)
        copyBytes(to: &raw, from: loc..<(loc + len))
        return NSString(bytes: raw, length: len, encoding: String.Encoding.utf8.rawValue)! as String
    }

    func cString(_ loc: Int, len: Int) -> String
    {
        var raw = Array<UInt8>(repeating: 0, count: len)
        copyBytes(to: &raw, from: loc..<(loc + len))
        return cStringRaw(raw, loc: loc, len: len)
    }

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

    func asArray() -> [UInt8] {
        var result = Array<UInt8>(repeating: 0, count: self.count)
        (self as NSData).getBytes(&result, length: self.count)
        return result
    }
}


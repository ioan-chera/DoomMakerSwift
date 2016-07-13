//
//  DataExtension.swift
//  DoomMakerSwift
//
//  Created by ioan on 24.01.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Foundation

func cString(data: [UInt8], loc: Int, len: Int) -> String
{
    var ret = ""
    for u in data
    {
        if u == 0
        {
            break
        }
        ret.append(UnicodeScalar(Int(u)))
    }
    return ret
}

func doubleFromInt16(data: [UInt8], loc: Int) -> Double
{
    return Double(Int(Int8(data[loc])) + (Int(Int8(data[loc + 1])) << 8))
}

func intFromInt16(data: [UInt8], loc: Int) -> Int
{
    return Int(Int8(bitPattern:data[loc])) + (Int(Int8(bitPattern:data[loc + 1])) << 8)
}

func subArray<T>(array: [T], loc: Int, len: Int) -> [T]
{
    return Array(array[loc...loc + len - 1])
}

private func cStringRaw(data: [UInt8], loc: Int, len: Int) -> String
{
    return cString(data, loc: loc, len: len)
}

extension NSData
{
    func string(loc: Int, len: Int) -> String
    {
        var raw = Array<UInt8>(count: len, repeatedValue: 0)
        getBytes(&raw, range: NSMakeRange(loc, len))
        return NSString(bytes: raw, length: len, encoding: NSUTF8StringEncoding)! as String
    }

    func cString(loc: Int, len: Int) -> String
    {
        var raw = Array<UInt8>(count: len, repeatedValue: 0)
        getBytes(&raw, range: NSMakeRange(loc, len))
        return cStringRaw(raw, loc: loc, len: len)
    }

    func int32(loc: Int) -> Int32
    {
        var raw = Array<UInt8>(count: 4, repeatedValue: 0)
        getBytes(&raw, range: NSMakeRange(loc, 4))
        var ret = Int32(raw[0])
        ret |= Int32(raw[1]) << 8
        ret |= Int32(raw[2]) << 16
        ret |= Int32(raw[3]) << 24
        return ret
    }

    func asArray() -> [UInt8] {
        var result = Array<UInt8>(count: self.length, repeatedValue: 0)
        self.getBytes(&result, length: self.length)
        return result
    }
}


//
//  DataExtension.swift
//  DoomMakerSwift
//
//  Created by ioan on 24.01.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Foundation

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
        var ret = ""
        for u in raw
        {
            if u == 0
            {
                break
            }
            ret.append(UnicodeScalar(Int(u)))
        }
        return ret
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
}
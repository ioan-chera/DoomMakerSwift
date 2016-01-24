//
//  Wad.swift
//  DoomMakerSwift
//
//  Created by ioan on 24.01.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Foundation

class Lump
{
    var name: String
    var data: [UInt8]

    init(name: String)
    {
        self.name = name.uppercaseString
        data = []
    }

    init(name: String, data: NSData)
    {
        self.name = name.uppercaseString
        self.data = Array<UInt8>(count: data.length, repeatedValue: 0)
        data.getBytes(&self.data, length: data.length)
    }
}

class Wad
{
    enum Type
    {
        case Iwad
        case Pwad
    }

    enum ReadError: ErrorType
    {
        case Info(text: String)
    }

    var type: Type
    var lumps: [Lump]

    init(inType: Type = Type.Pwad)
    {
        type = inType
        lumps = []
    }

    func read(data: NSData) throws
    {
        if data.length < 12 || data.length > 0x7fffffff  // also handle int32 overflows
        {
            throw ReadError.Info(text: "File size invalid")
        }

        guard let newType: Type = ["IWAD": Type.Iwad, "PWAD": Type.Pwad][data.string(0, len: 4)] else
        {
            throw ReadError.Info(text: "File is not a PWAD or IWAD")
        }

        let numLumps = data.int32(4)
        let infoTableOfs = data.int32(8)

        if numLumps < 0 || numLumps * 16 < 0 || numLumps > 0 && infoTableOfs + 16 * numLumps > Int32(data.length)
        {
            throw ReadError.Info(text: "WAD file is corrupted")
        }

        var newLumps: [Lump] = []

        for var i = 0; i < Int(numLumps); ++i
        {
            let address = Int(infoTableOfs + 16 * i)
            let filepos = data.int32(address)
            let size = data.int32(address + 4)
            let name = data.cString(address + 8, len: 8)
            // check validity
            if size < 0 || size > 0 && (filepos < 0 || filepos + size > Int32(data.length) || filepos + size < 0)
            {
                throw ReadError.Info(text: "WAD file is corrupted at lump " + name)
            }
            newLumps.append(Lump(name: name, data: data.subdataWithRange(NSMakeRange(Int(filepos), Int(size)))))
        }

        // ok
        type = newType
        lumps = newLumps
    }
}

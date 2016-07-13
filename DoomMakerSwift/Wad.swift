//
//  Wad.swift
//  DoomMakerSwift
//
//  Created by ioan on 24.01.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Foundation



///
/// Wad file data. Contains the kind (IWAD or PWAD) and lump list (array)
///
class Wad
{
    ///
    /// IWAD or PWAD, based on file header
    ///
    enum Type
    {
        case Iwad
        case Pwad
    }

    ///
    /// Read error throwable
    ///
    enum ReadError: ErrorType
    {
        case Info(text: String)
    }

    private(set) var type: Type
    private(set) var lumps: [Lump]

    init(inType: Type = Type.Pwad)
    {
        type = inType
        lumps = []
    }

    ///
    /// Reads from NSData. Throws ReadError.Info(text) on failure.
    ///
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

        for i in 0..<Int(numLumps)
        {
            let address = Int(infoTableOfs + 16 * i)
            let filepos = data.int32(address)
            let size = data.int32(address + 4)
            let nameData = data.subdataWithRange(NSMakeRange(address + 8, 8))

            // check validity
            if size < 0 || size > 0 && (filepos < 0 || filepos + size > Int32(data.length) || filepos + size < 0)
            {
                throw ReadError.Info(text: "WAD file is corrupted at lump '\(String(nameData))' index \(i)")
            }

            let data = data.subdataWithRange(NSMakeRange(Int(filepos), Int(size)))
            
            newLumps.append(Lump(nameData: nameData, data: data))
        }

        // ok
        self.type = newType
        self.lumps = newLumps
    }


}

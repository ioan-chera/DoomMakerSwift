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
/// Wad file data. Contains the kind (IWAD or PWAD) and lump list (array)
///
class Wad
{
    ///
    /// IWAD or PWAD, based on file header
    ///
    enum WadType
    {
        case iwad
        case pwad
    }

    private(set) var type: WadType
    private(set) var lumps: [Lump]

    init(inType: WadType = WadType.pwad)
    {
        type = inType
        lumps = []
    }

    ///
    /// Adds a lump
    ///
    func add(lump: Lump) {
        lumps.append(lump)
    }

    func replace(lumpAtIndex index: Int, with lump: Lump) {
        lumps[index] = lump
    }

    ///
    /// Reads from NSData. Throws ReadError.Info(text) on failure.
    ///
    func read(_ data: Data) throws
    {
        if data.count < 12 || data.count > 0x7fffffff  // also handle int32 overflows
        {
            throw DMError.wadReading(info: "File size invalid")
        }

        guard let newType: WadType = ["IWAD": WadType.iwad, "PWAD": WadType.pwad][data.string(0, len: 4)] else
        {
            throw DMError.wadReading(info: "File is not a PWAD or IWAD")
        }

        let numLumps = data.int32(4)
        let infoTableOfs = data.int32(8)

        if numLumps < 0 || numLumps * 16 < 0 || numLumps > 0 && infoTableOfs + 16 * numLumps > Int32(data.count)
        {
            throw DMError.wadReading(info: "WAD file is corrupted")
        }

        var newLumps: [Lump] = []

        for i in 0..<Int(numLumps)
        {
            let address = Int(infoTableOfs) + 16 * i
            let filepos = data.int32(address)
            let size = data.int32(address + 4)
            let nameData = data.subdata(in: (address + 8) ..< (address + 16))

            // check validity
            if size < 0 || size > 0 && (filepos < 0 || filepos + size > Int32(data.count) || filepos + size < 0)
            {
                throw DMError.wadReading(info: "WAD file is corrupted at lump '\(String(describing: nameData))' index \(i)")
            }

            let data = data.subdata(in: Int(filepos) ..< (Int(filepos) + Int(size)))
            
            newLumps.append(Lump(nameData: nameData, data: data))
        }

        // ok
        self.type = newType
        self.lumps = newLumps
    }

    func serialized() -> Data  {
        var data : [UInt8] = []
        var infotableofs = Int32(12)
        data += self.type == WadType.iwad ? [UInt8]("IWAD".utf8) : [UInt8]("PWAD".utf8)
        data += bytesFromInt32(Int32(self.lumps.count))
        data += [0, 0, 0, 0]    // to be set later

        var addresses : [Int32] = []

        for lump in lumps {
            data += lump.data
            addresses.append(infotableofs)
            infotableofs += Int32(lump.data.count)
        }
        data.replaceSubrange(8..<12, with: bytesFromInt32(infotableofs))
        var i = 0
        for lump in lumps {
            data += bytesFromInt32(addresses[i])
            data += bytesFromInt32(Int32(lump.data.count))
            data += lump.nameBytes
            if lump.nameBytes.count < 8 {
                data += [UInt8](repeating: 0, count: 8 - lump.nameBytes.count)
            }

            i += 1
        }

        return Data(data);
    }
}

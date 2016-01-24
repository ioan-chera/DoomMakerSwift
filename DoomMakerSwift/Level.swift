//
//  Level.swift
//  DoomMakerSwift
//
//  Created by ioan on 24.01.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Foundation

enum LevelError: ErrorType
{
    case Info(text: String)
}

///
/// Map vertex
///
class Vertex
{
    /// double because we want compatibility with UDMF
    var x, y: Double
    init(x: Double, y: Double)
    {
        self.x = x
        self.y = y
    }
    init(data: [UInt8])
    {
        self.x = doubleFromInt16(data, loc: 0)
        self.y = doubleFromInt16(data, loc: 2)
    }
}

///
/// Map sector
///
class Sector
{
    var floorheight, ceilingheight: Double  // not even UDMF supports this
    var floorpic, ceilingpic: String
    var lightlevel: Int = 160
    var special: Int = 0
    var tag: Int = 0

    init(floorheight: Double, ceilingheight: Double, floorpic: String, ceilingpic: String)
    {
        self.floorheight = floorheight
        self.ceilingheight = ceilingheight
        self.floorpic = floorpic
        self.ceilingpic = ceilingpic
    }
    init(data: [UInt8])
    {
        self.floorheight = doubleFromInt16(data, loc: 0)
        self.ceilingheight = doubleFromInt16(data, loc: 2)
        self.floorpic = cString(data, loc: 4, len: 8)
        self.ceilingpic = cString(data, loc: 12, len: 8)
        self.lightlevel = intFromInt16(data, loc: 20)
        self.special = intFromInt16(data, loc: 22)
        self.tag = intFromInt16(data, loc: 24)
    }
}

///
/// Map sidedef
///
class Sidedef
{
    var xoffset = Double(0)
    var yoffset = Double(0)
    var uppertex = "-"
    var midtex = "-"
    var lowertex = "-"
    var sector: Sector!

    init(sector: Sector)
    {
        self.sector = sector
    }

    init?(data: [UInt8], sectors: [Sector])
    {
        let index = intFromInt16(data, loc: 28)
        if index < 0 || index >= sectors.count
        {
            return nil
        }
        self.xoffset = doubleFromInt16(data, loc: 0)
        self.yoffset = doubleFromInt16(data, loc: 2)
        self.uppertex = cString(data, loc: 4, len: 8)
        self.lowertex = cString(data, loc: 12, len: 8)
        self.midtex = cString(data, loc: 20, len: 8)
        self.sector = sectors[index]
    }
}

///
/// Map linedef
///
class Linedef
{
    var v: (Vertex, Vertex)!
    var flags = UInt(0)
    var special = 0
    var tag = 0
    var sides: (Sidedef, Sidedef?)!

    init(v: (Vertex, Vertex), side: Sidedef)
    {
        self.v = v
        self.sides = (side, nil)
    }

    init?(data: [UInt8], vertices: [Vertex], sidedefs: [Sidedef])
    {
        var index = intFromInt16(data, loc: 0)
        if index < 0 || index >= vertices.count
        {
            return nil
        }
        self.v.0 = vertices[index]
        index = intFromInt16(data, loc: 2)
        if index < 0 || index >= vertices.count
        {
            return nil
        }
        self.v.1 = vertices[index]
        self.flags = UInt(intFromInt16(data, loc: 4))
        self.special = intFromInt16(data, loc: 6)
        self.tag = intFromInt16(data, loc: 8)
        index = intFromInt16(data, loc: 10)
        if index < 0 || index >= sidedefs.count
        {
            return nil
        }
        self.sides.0 = sidedefs[index]
        index = intFromInt16(data, loc: 12)
        if index < -1 || index >= sidedefs.count
        {
            return nil
        }
        self.sides.1 = index == -1 ? nil : sidedefs[index]
    }
}

///
/// Map thing
///
class Thing
{
    var x, y: Double
    var angle = 0
    var type: Int
    var flags = UInt(0)

    init(x: Double, y: Double, type: Int)
    {
        self.x = x
        self.y = y
        self.type = type
    }

    init(data: [UInt8])
    {
        self.x = doubleFromInt16(data, loc: 0)
        self.y = doubleFromInt16(data, loc: 2)
        self.angle = intFromInt16(data, loc: 4)
        self.type = intFromInt16(data, loc: 6)
        self.flags = UInt(intFromInt16(data, loc: 8))
    }
}

///
/// Level processed data
///
class Level
{
    var vertices: [Vertex] = []
    var sectors: [Sector] = []
    var sidedefs: [Sidedef] = []
    var linedefs: [Linedef] = []
    var things: [Thing] = []

    ///
    /// This assumes the index has been validated for the existence of level
    /// lumps. But will still throw if any lump is inconsistent
    ///
    init(wad: Wad, lumpIndex: Int) throws
    {
        let name = wad.lumps[lumpIndex].name
        let verticesLump = wad.lumps[lumpIndex + 4]
        if verticesLump.data.count % 4 != 0
        {
            throw LevelError.Info(text: "Invalid VERTEXES lump for " + name)
        }
        var newVertices: [Vertex] = []
        for var i = 0; i < verticesLump.data.count; i += 4
        {
            newVertices.append(Vertex(data: subArray(verticesLump.data, loc: i, len: 4)))
        }

        let sectorsLump = wad.lumps[lumpIndex + 8]
        if sectorsLump.data.count % 26 != 0
        {
            throw LevelError.Info(text: "Invalid SECTORS lump for " + name)
        }
        var newSectors: [Sector] = []
        for var i = 0; i < sectorsLump.data.count; i += 26
        {
            newSectors.append(Sector(data: Array(sectorsLump.data[i...i + 25])))
        }

        let sidedefsLump = wad.lumps[lumpIndex + 3]
        if sidedefsLump.data.count % 30 != 0
        {
            throw LevelError.Info(text: "Invalid SIDEDEFS lump for " + name)
        }
        var newSidedefs: [Sidedef] = []
        for var i = 0; i < sidedefsLump.data.count; i += 30
        {
            guard let sidedef = Sidedef(data: Array(sidedefsLump.data[i...i + 29]), sectors: sectors) else
            {
                throw LevelError.Info(text: "Invalid sector reference for sidedef " + String(i / 30) + " in " + name)
            }
            newSidedefs.append(sidedef)
        }

        let linedefsLump = wad.lumps[lumpIndex + 2]
        if linedefsLump.data.count % 14 != 0
        {
            throw LevelError.Info(text: "Invalid LINEDEFS lump for " + name)
        }
        var newLinedefs: [Linedef] = []
        for var i = 0; i < linedefsLump.data.count; i += 14
        {
            guard let linedef = Linedef(data: Array(linedefsLump.data[i...i + 13]), vertices: vertices, sidedefs: sidedefs) else
            {
                throw LevelError.Info(text: "Invalid references for linedef " + String(i / 14) + " in " + name)
            }
            newLinedefs.append(linedef)
        }

        let thingsLump = wad.lumps[lumpIndex + 1]
        if thingsLump.data.count % 10 != 0
        {
            throw LevelError.Info(text: "Invalid THINGS lump for " + name)
        }
        var newThings: [Thing] = []
        for var i = 0; i < thingsLump.data.count; i += 10
        {
            newThings.append(Thing(data: Array(thingsLump.data[i...i + 9])))
        }

        vertices = newVertices
        sectors = newSectors
        sidedefs = newSidedefs
        linedefs = newLinedefs
        things = newThings
    }
}
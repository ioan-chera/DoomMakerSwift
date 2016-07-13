//
//  Level.swift
//  DoomMakerSwift
//
//  Created by ioan on 24.01.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Foundation

///
/// Map vertex
///
//class Vertex
//{
//    /// double because we want compatibility with UDMF
//    var x, y: Double
//    init(x: Double, y: Double)
//    {
//        self.x = x
//        self.y = y
//    }
//    init(data: [UInt8])
//    {
//        self.x = doubleFromInt16(data, loc: 0)
//        self.y = doubleFromInt16(data, loc: 2)
//    }
//}

///
/// Map sector
///
//class Sector
//{
//    var floorheight, ceilingheight: Double  // not even UDMF supports this
//    var floorpic, ceilingpic: String
//    var lightlevel: Int = 160
//    var special: Int = 0
//    var tag: Int = 0
//
//    init(floorheight: Double, ceilingheight: Double, floorpic: String, ceilingpic: String)
//    {
//        self.floorheight = floorheight
//        self.ceilingheight = ceilingheight
//        self.floorpic = floorpic
//        self.ceilingpic = ceilingpic
//    }
//    init(data: [UInt8])
//    {
//        self.floorheight = doubleFromInt16(data, loc: 0)
//        self.ceilingheight = doubleFromInt16(data, loc: 2)
//        self.floorpic = cString(data, loc: 4, len: 8)
//        self.ceilingpic = cString(data, loc: 12, len: 8)
//        self.lightlevel = intFromInt16(data, loc: 20)
//        self.special = intFromInt16(data, loc: 22)
//        self.tag = intFromInt16(data, loc: 24)
//    }
//}

///
/// Map sidedef
///
//class Sidedef
//{
//    var xoffset = Double(0)
//    var yoffset = Double(0)
//    var uppertex = "-"
//    var midtex = "-"
//    var lowertex = "-"
//    var sectorIndex: Sector!
//
//    init(sector: Sector)
//    {
//        self.sector = sector
//    }
//
//    init?(data: [UInt8], sectors: [Sector])
//    {
//        let index = intFromInt16(data, loc: 28)
//        if index < 0 || index >= sectors.count
//        {
//            return nil
//        }
//        self.xoffset = doubleFromInt16(data, loc: 0)
//        self.yoffset = doubleFromInt16(data, loc: 2)
//        self.uppertex = cString(data, loc: 4, len: 8)
//        self.lowertex = cString(data, loc: 12, len: 8)
//        self.midtex = cString(data, loc: 20, len: 8)
//        self.sector = sectors[index]
//    }
//}

///
/// Map linedef
///
//class Linedef
//{
//    var v: (Vertex, Vertex)!
//    var flags = UInt(0)
//    var special = 0
//    var tag = 0
//    var sides: (Sidedef, Sidedef?)!
//
//    init(v: (Vertex, Vertex), side: Sidedef)
//    {
//        self.v = v
//        self.sides = (side, nil)
//    }
//
//    init?(data: [UInt8], vertices: [Vertex], sidedefs: [Sidedef])
//    {
//        var index = intFromInt16(data, loc: 0)
//        if index < 0 || index >= vertices.count
//        {
//            return nil
//        }
//        self.v.0 = vertices[index]
//        index = intFromInt16(data, loc: 2)
//        if index < 0 || index >= vertices.count
//        {
//            return nil
//        }
//        self.v.1 = vertices[index]
//        self.flags = UInt(intFromInt16(data, loc: 4))
//        self.special = intFromInt16(data, loc: 6)
//        self.tag = intFromInt16(data, loc: 8)
//        index = intFromInt16(data, loc: 10)
//        if index < 0 || index >= sidedefs.count
//        {
//            return nil
//        }
//        self.sides.0 = sidedefs[index]
//        index = intFromInt16(data, loc: 12)
//        if index < -1 || index >= sidedefs.count
//        {
//            return nil
//        }
//        self.sides.1 = index == -1 ? nil : sidedefs[index]
//    }
//}

///
/// Map thing
///
//
//
//
//
//
//
//struct Se

///
/// Level processed data
///
class Level
{
//    var vertices: [Vertex] = []
//    var sectors: [Sector] = []
//    var sidedefs: [Sidedef] = []
//    var linedefs: [Linedef] = []
//    var things: [Thing] = []
    enum LoadError: ErrorType
    {
        case Info(text: String)
    }

    // This will allow both getting the lump name and lump index
    enum LumpOffset: Int {
        case Things = 1
        case Linedefs
        case Sidedefs
        case Vertices
        case Segs
        case Subsectors
        case Nodes
        case Sectors
        case Reject
        case Blockmap
    }

    struct LumpDefinition {
        let name: String
        let recordSize: Int
    }

    static let lumpMap: [LumpOffset: LumpDefinition] = [
        .Things: LumpDefinition(name: "THINGS", recordSize: 10),
        .Linedefs: LumpDefinition(name: "LINEDEFS", recordSize: 14),
        .Sidedefs: LumpDefinition(name: "SIDEDEFS", recordSize: 30),
        .Vertices: LumpDefinition(name: "VERTEXES", recordSize: 4),
        .Segs: LumpDefinition(name: "SEGS", recordSize: 12),
        .Subsectors: LumpDefinition(name: "SSECTORS", recordSize: 4),
        .Nodes: LumpDefinition(name: "NODES", recordSize: 28),
        .Sectors: LumpDefinition(name: "SECTORS", recordSize: 26),
        .Reject: LumpDefinition(name: "REJECT", recordSize: 1),
        .Blockmap: LumpDefinition(name: "BLOCKMAP", recordSize: 2)
    ]

    struct Thing {
        var x = 0
        var y = 0
        var angle = 0
        var type = 0
        var flags = 0

        init(data: [UInt8]) {
            x = intFromInt16(data, loc: 0)
            y = intFromInt16(data, loc: 2)
            angle = intFromInt16(data, loc: 4)
            type = intFromInt16(data, loc: 6)
            flags = intFromInt16(data, loc: 8)
        }
    }

    struct Linedef {
        var v1 = 0
        var v2 = 0
        var flags = 0
        var special = 0
        var tag = 0
        var s1 = 0
        var s2 = 0

        init(data: [UInt8]) {
            v1 = intFromInt16(data, loc: 0)
            v2 = intFromInt16(data, loc: 2)
            flags = intFromInt16(data, loc: 4)
            special = intFromInt16(data, loc: 6)
            tag = intFromInt16(data, loc: 8)
            s1 = intFromInt16(data, loc: 10)
            s2 = intFromInt16(data, loc: 12)
        }
    }

    struct Sidedef {
        var xOffset = 0
        var yOffset = 0
        var upper: [UInt8] = []
        var lower: [UInt8] = []
        var middle: [UInt8] = []
        var sector = 0

        init(data: [UInt8]) {
            xOffset = intFromInt16(data, loc: 0)
            yOffset = intFromInt16(data, loc: 2)
            upper = Lump.truncateZero(Array(data[4..<12]))
            lower = Lump.truncateZero(Array(data[12..<20]))
            middle = Lump.truncateZero(Array(data[20..<28]))
            sector = intFromInt16(data, loc: 28)
        }
    }

    struct Vertex {
        var x = 0
        var y = 0

        init(data: [UInt8]) {
            x = intFromInt16(data, loc: 0)
            y = intFromInt16(data, loc: 2)
        }
    }

    struct Seg {
        var v1 = 0
        var v2 = 0
        var angle = 0
        var line = 0
        var dir = 0
        var offset = 0

        init(data: [UInt8]) {
            v1 = intFromInt16(data, loc: 0)
            v2 = intFromInt16(data, loc: 2)
            angle = intFromInt16(data, loc: 4)
            line = intFromInt16(data, loc: 6)
            dir = intFromInt16(data, loc: 8)
            offset = intFromInt16(data, loc: 10)
        }
    }

    struct Subsector {
        var segCount = 0
        var firstSeg = 0

        init(data: [UInt8]) {
            segCount = intFromInt16(data, loc: 0)
            firstSeg = intFromInt16(data, loc: 2)
        }
    }

    struct Node {
        var x0 = 0
        var y0 = 0
        var dx = 0
        var dy = 0
        var rightBox = (top:0, bottom:0, left:0, right:0)
        var leftBox = (top:0, bottom:0, left:0, right:0)
        var rightChild = 0
        var leftChild = 0

        init(data: [UInt8]) {
            x0 = intFromInt16(data, loc: 0)
            y0 = intFromInt16(data, loc: 2)
            dx = intFromInt16(data, loc: 4)
            dy = intFromInt16(data, loc: 6)
            rightBox.top = intFromInt16(data, loc: 8)
            rightBox.bottom = intFromInt16(data, loc: 10)
            rightBox.left = intFromInt16(data, loc: 12)
            rightBox.right = intFromInt16(data, loc: 14)
            leftBox.top = intFromInt16(data, loc: 16)
            leftBox.bottom = intFromInt16(data, loc: 18)
            leftBox.left = intFromInt16(data, loc: 20)
            leftBox.right = intFromInt16(data, loc: 22)
            rightChild = intFromInt16(data, loc: 24)
            leftChild = intFromInt16(data, loc: 26)
        }
    }

    struct Sector {
        var floorheight = 0
        var ceilingheight = 0
        var floor: [UInt8] = []
        var ceiling: [UInt8] = []
        var light = 0
        var special = 0
        var tag = 0

        init(data: [UInt8]) {
            floorheight = intFromInt16(data, loc: 0)
            ceilingheight = intFromInt16(data, loc: 2)
            floor = Lump.truncateZero(Array(data[4..<12]))
            ceiling = Lump.truncateZero(Array(data[12..<20]))
            light = intFromInt16(data, loc: 20)
            special = intFromInt16(data, loc: 22)
            tag = intFromInt16(data, loc: 24)
        }
    }

    private var name: String

    private var things: [Thing]
    private var linedefs: [Linedef]
    private var sidedefs: [Sidedef]
    private var vertices: [Vertex]
    private var segs: [Seg]
    private var subsectors: [Subsector]
    private var nodes: [Node]
    private var sectors: [Sector]
    private var reject: [UInt8]
    private var blockmap: [Int]

    init(wad: Wad, lumpIndex: Int) {
        self.name = wad.lumps[lumpIndex].name
        self.things = []
        self.linedefs = []
        self.sidedefs = []
        self.vertices = []
        self.segs = []
        self.subsectors = []
        self.nodes = []
        self.sectors = []
        self.reject = []
        self.blockmap = []

        let thingsData = wad.lumps[lumpIndex + LumpOffset.Things.rawValue].data
        self.loadThings(thingsData)
        let linedefsData = wad.lumps[lumpIndex + LumpOffset.Linedefs.rawValue].data
        self.loadLinedefs(linedefsData)
        let sidedefsData = wad.lumps[lumpIndex + LumpOffset.Sidedefs.rawValue].data
        self.loadSidedefs(sidedefsData)
        let verticesData = wad.lumps[lumpIndex + LumpOffset.Vertices.rawValue].data
        self.loadVertices(verticesData)
        let segsData = wad.lumps[lumpIndex + LumpOffset.Segs.rawValue].data
        self.loadSegs(segsData)
        let subsectorsData = wad.lumps[lumpIndex + LumpOffset.Subsectors.rawValue].data
        self.loadSubsectors(subsectorsData)
        let nodesData = wad.lumps[lumpIndex + LumpOffset.Nodes.rawValue].data
        self.loadNodes(nodesData)
        let sectorsData = wad.lumps[lumpIndex + LumpOffset.Sectors.rawValue].data
        self.loadSectors(sectorsData)
        self.reject = wad.lumps[lumpIndex + LumpOffset.Reject.rawValue].data
        let blockmapData = wad.lumps[lumpIndex + LumpOffset.Blockmap.rawValue].data
        self.loadBlockmap(blockmapData)
    }

    private func loadThings(thingsData: [UInt8]) {
        self.things = []
        let recordSize = Level.lumpMap[.Things]!.recordSize
        for i in 0.stride(to: thingsData.count, by: recordSize) {
            let slice = thingsData[i ..< i + recordSize]
            self.things.append(Thing(data: Array(slice)))
        }
    }

    private func loadLinedefs(linedefsData: [UInt8]) {
        self.linedefs = []
        let recordSize = Level.lumpMap[.Linedefs]!.recordSize
        for i in 0.stride(to: linedefsData.count, by: recordSize) {
            let slice = linedefsData[i ..< i + recordSize]
            self.linedefs.append(Linedef(data: Array(slice)))
        }
    }

    private func loadSidedefs(sidedefsData: [UInt8]) {
        self.sidedefs = []
        let recordSize = Level.lumpMap[.Sidedefs]!.recordSize
        for i in 0.stride(to: sidedefsData.count, by: recordSize) {
            let slice = sidedefsData[i ..< i + recordSize]
            self.sidedefs.append(Sidedef(data: Array(slice)))
        }
    }

    private func loadVertices(verticesData: [UInt8]) {
        self.vertices = []
        let recordSize = Level.lumpMap[.Vertices]!.recordSize
        for i in 0.stride(to: verticesData.count, by: recordSize) {
            let slice = verticesData[i ..< i + recordSize]
            self.vertices.append(Vertex(data: Array(slice)))
        }
    }

    private func loadSegs(segsData: [UInt8]) {
        self.segs = []
        let recordSize = Level.lumpMap[.Segs]!.recordSize
        for i in 0.stride(to: segsData.count, by: recordSize) {
            let slice = segsData[i ..< i + recordSize]
            self.segs.append(Seg(data: Array(slice)))
        }
    }

    private func loadSubsectors(subsectorsData: [UInt8]) {
        self.subsectors = []
        let recordSize = Level.lumpMap[.Subsectors]!.recordSize
        for i in 0.stride(to: subsectorsData.count, by: recordSize) {
            let slice = subsectorsData[i ..< i + recordSize]
            self.subsectors.append(Subsector(data: Array(slice)))
        }
    }

    private func loadNodes(nodesData: [UInt8]) {
        self.nodes = []
        let recordSize = Level.lumpMap[.Nodes]!.recordSize
        for i in 0.stride(to: nodesData.count, by: recordSize) {
            let slice = nodesData[i ..< i + recordSize]
            self.nodes.append(Node(data: Array(slice)))
        }
    }

    private func loadSectors(sectorsData: [UInt8]) {
        self.sectors = []
        let recordSize = Level.lumpMap[.Sectors]!.recordSize
        for i in 0.stride(to: sectorsData.count, by: recordSize) {
            let slice = sectorsData[i ..< i + recordSize]
            self.sectors.append(Sector(data: Array(slice)))
        }
    }

    private func loadBlockmap(blockmapData: [UInt8]) {
        self.blockmap = []
        let recordSize = Level.lumpMap[.Blockmap]!.recordSize
        for i in 0.stride(to: blockmapData.count, by: recordSize) {
            self.blockmap.append(intFromInt16(blockmapData, loc: i))
        }
    }

    ///
    /// This assumes the index has been validated for the existence of level
    /// lumps. But will still throw if any lump is inconsistent
    ///
//    init(wad: Wad, lumpIndex: Int) throws
//    {
//        let name = wad.lumps[lumpIndex].name
//        let verticesLump = wad.lumps[lumpIndex + 4]
//        if verticesLump.data.count % 4 != 0
//        {
//            throw LevelError.Info(text: "Invalid VERTEXES lump for " + name)
//        }
//        var newVertices: [Vertex] = []
//        for var i = 0; i < verticesLump.data.count; i += 4
//        {
//            newVertices.append(Vertex(data: subArray(verticesLump.data, loc: i, len: 4)))
//        }
//
//        let sectorsLump = wad.lumps[lumpIndex + 8]
//        if sectorsLump.data.count % 26 != 0
//        {
//            throw LevelError.Info(text: "Invalid SECTORS lump for " + name)
//        }
//        var newSectors: [Sector] = []
//        for var i = 0; i < sectorsLump.data.count; i += 26
//        {
//            newSectors.append(Sector(data: Array(sectorsLump.data[i...i + 25])))
//        }
//
//        let sidedefsLump = wad.lumps[lumpIndex + 3]
//        if sidedefsLump.data.count % 30 != 0
//        {
//            throw LevelError.Info(text: "Invalid SIDEDEFS lump for " + name)
//        }
//        var newSidedefs: [Sidedef] = []
//        for var i = 0; i < sidedefsLump.data.count; i += 30
//        {
//            guard let sidedef = Sidedef(data: Array(sidedefsLump.data[i...i + 29]), sectors: sectors) else
//            {
//                throw LevelError.Info(text: "Invalid sector reference for sidedef " + String(i / 30) + " in " + name)
//            }
//            newSidedefs.append(sidedef)
//        }
//
//        let linedefsLump = wad.lumps[lumpIndex + 2]
//        if linedefsLump.data.count % 14 != 0
//        {
//            throw LevelError.Info(text: "Invalid LINEDEFS lump for " + name)
//        }
//        var newLinedefs: [Linedef] = []
//        for var i = 0; i < linedefsLump.data.count; i += 14
//        {
//            guard let linedef = Linedef(data: Array(linedefsLump.data[i...i + 13]), vertices: vertices, sidedefs: sidedefs) else
//            {
//                throw LevelError.Info(text: "Invalid references for linedef " + String(i / 14) + " in " + name)
//            }
//            newLinedefs.append(linedef)
//        }
//
//        let thingsLump = wad.lumps[lumpIndex + 1]
//        if thingsLump.data.count % 10 != 0
//        {
//            throw LevelError.Info(text: "Invalid THINGS lump for " + name)
//        }
//        var newThings: [Thing] = []
//        for var i = 0; i < thingsLump.data.count; i += 10
//        {
//            newThings.append(Thing(data: Array(thingsLump.data[i...i + 9])))
//        }
//
//        vertices = newVertices
//        sectors = newSectors
//        sidedefs = newSidedefs
//        linedefs = newLinedefs
//        things = newThings
//    }
}
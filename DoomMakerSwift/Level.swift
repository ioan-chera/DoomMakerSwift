//
//  Level.swift
//  DoomMakerSwift
//
//  Created by ioan on 24.01.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Foundation

private protocol MapItem {
    init(data: [UInt8])
}

///
/// Level processed data
///
class Level
{
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

    final class Thing: MapItem {
        var x = 0
        var y = 0
        var angle = 0
        var type = 0
        var flags = 0

        init(data: [UInt8]) {
            DataReader(data).short(&x).short(&y).short(&angle).short(&type).short(&flags)
        }
    }

    final class Linedef: MapItem {
        var v1 = 0
        var v2 = 0
        var flags = 0
        var special = 0
        var tag = 0
        var s1 = 0
        var s2 = 0

        init(data: [UInt8]) {
            DataReader(data).short(&v1).short(&v2).short(&flags).short(&special).short(&tag).short(&s1).short(&s2)
        }
    }

    final class Sidedef: MapItem {
        var xOffset = 0
        var yOffset = 0
        var upper: [UInt8] = []
        var lower: [UInt8] = []
        var middle: [UInt8] = []
        var sector = 0

        init(data: [UInt8]) {
            DataReader(data).short(&xOffset).short(&yOffset).lumpName(&upper).lumpName(&lower).lumpName(&middle).short(&sector)
        }
    }

    final class Vertex: MapItem {
        var x = 0
        var y = 0

        var degree = 0  // number of adjacent lines

        init(data: [UInt8]) {
            DataReader(data).short(&x).short(&y)
        }
    }

    final class Seg: MapItem {
        var v1 = 0
        var v2 = 0
        var angle = 0
        var line = 0
        var dir = 0
        var offset = 0

        init(data: [UInt8]) {
            DataReader(data).short(&v1).short(&v2).short(&angle).short(&line).short(&dir).short(&offset)
        }
    }

    final class Subsector: MapItem {
        var segCount = 0
        var firstSeg = 0

        init(data: [UInt8]) {
            DataReader(data).short(&segCount).short(&firstSeg)
        }
    }

    final class Node: MapItem {
        var x0 = 0
        var y0 = 0
        var dx = 0
        var dy = 0
        var rightBox = (top:0, bottom:0, left:0, right:0)
        var leftBox = (top:0, bottom:0, left:0, right:0)
        var rightChild = 0
        var leftChild = 0

        init(data: [UInt8]) {
            DataReader(data).short(&x0).short(&y0).short(&dx).short(&dy)
                .short(&rightBox.top).short(&rightBox.bottom).short(&rightBox.left).short(&rightBox.right)
                .short(&leftBox.top).short(&leftBox.bottom).short(&leftBox.left).short(&leftBox.right)
                .short(&rightChild).short(&leftChild)
        }
    }

    final class Sector: MapItem {
        var floorheight = 0
        var ceilingheight = 0
        var floor: [UInt8] = []
        var ceiling: [UInt8] = []
        var light = 0
        var special = 0
        var tag = 0

        init(data: [UInt8]) {
            DataReader(data).short(&floorheight).short(&ceilingheight).lumpName(&floor).lumpName(&ceiling).short(&light).short(&special).short(&tag)
        }
    }

    private(set) var name: String

    private(set) var things: [Thing]
    private(set) var linedefs: [Linedef]
    private var sidedefs: [Sidedef]
    private(set) var vertices: [Vertex]
    private var segs: [Seg]
    private var subsectors: [Subsector]
    private var nodes: [Node]
    private var sectors: [Sector]
    private var reject: [UInt8]
    private var blockmap: [Int]

    init(wad: Wad, lumpIndex: Int) {
        func loadItems<T: MapItem>(type: LumpOffset) -> [T] {
            let data = wad.lumps[lumpIndex + type.rawValue].data
            var list: [T] = []
            let recordSize = Level.lumpMap[type]!.recordSize
            for i in 0.stride(to: data.count, by: recordSize) {
                let slice = data[i ..< i + recordSize]
                list.append(T(data: Array(slice)))
            }
            return list
        }

        self.name = wad.lumps[lumpIndex].name

        self.things = loadItems(.Things)
        self.linedefs = loadItems(.Linedefs)
        self.sidedefs = loadItems(.Sidedefs)
        self.vertices = loadItems(.Vertices)
        self.segs = loadItems(.Segs)
        self.subsectors = loadItems(.Subsectors)
        self.nodes = loadItems(.Nodes)
        self.sectors = loadItems(.Sectors)

        self.reject = wad.lumps[lumpIndex + LumpOffset.Reject.rawValue].data
        self.blockmap = []
        self.loadBlockmap(wad.lumps[lumpIndex + LumpOffset.Blockmap.rawValue].data)

        postprocess()
    }

    private func loadBlockmap(blockmapData: [UInt8]) {
        self.blockmap = []
        let recordSize = Level.lumpMap[.Blockmap]!.recordSize
        for i in 0.stride(to: blockmapData.count, by: recordSize) {
            self.blockmap.append(intFromInt16(blockmapData, loc: i))
        }
    }

    private func postprocess() {
        for line in linedefs {
            if line.v1 < 0 || line.v1 >= vertices.count || line.v2 < 0 || line.v2 >= vertices.count {
                continue
            }
            vertices[line.v1].degree += 1
            vertices[line.v2].degree += 1
        }
    }
}
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
    enum LoadError: Error
    {
        case info(text: String)
    }

    // This will allow both getting the lump name and lump index
    enum LumpOffset: Int {
        case things = 1
        case linedefs
        case sidedefs
        case vertices
        case segs
        case subsectors
        case nodes
        case sectors
        case reject
        case blockmap
    }

    struct LumpDefinition {
        let name: String
        let recordSize: Int
    }

    static let lumpMap: [LumpOffset: LumpDefinition] = [
        .things: LumpDefinition(name: "THINGS", recordSize: 10),
        .linedefs: LumpDefinition(name: "LINEDEFS", recordSize: 14),
        .sidedefs: LumpDefinition(name: "SIDEDEFS", recordSize: 30),
        .vertices: LumpDefinition(name: "VERTEXES", recordSize: 4),
        .segs: LumpDefinition(name: "SEGS", recordSize: 12),
        .subsectors: LumpDefinition(name: "SSECTORS", recordSize: 4),
        .nodes: LumpDefinition(name: "NODES", recordSize: 28),
        .sectors: LumpDefinition(name: "SECTORS", recordSize: 26),
        .reject: LumpDefinition(name: "REJECT", recordSize: 1),
        .blockmap: LumpDefinition(name: "BLOCKMAP", recordSize: 2)
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

    final class Vertex: MapItem, Hashable {
        var x = 0
        var y = 0

        var degree = 0  // number of adjacent lines

        init(data: [UInt8]) {
            DataReader(data).short(&x).short(&y)
        }

        var hashValue: Int {
            get {
                return x.hashValue ^ y.hashValue
            }
        }

        static func == (lhs: Vertex, rhs: Vertex) -> Bool {
            return lhs === rhs
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

    fileprivate(set) var name: String

    fileprivate(set) var things: [Thing]
    fileprivate(set) var linedefs: [Linedef]
    fileprivate var sidedefs: [Sidedef]
    fileprivate(set) var vertices: [Vertex]
    fileprivate var segs: [Seg]
    fileprivate var subsectors: [Subsector]
    fileprivate var nodes: [Node]
    fileprivate var sectors: [Sector]
    fileprivate var reject: [UInt8]
    fileprivate var blockmap: [Int]

    /// the vertex currently highlighted by the mouse
    private(set) var highlightedVertexIndex: Int?

    /// the vertex the user started holding down the mouse
    private(set) var clickedDownVertexIndex: Int?

    /// the map position the user started holding down the mouse
    private var clickedDownOffset = NSSize()

    /// The grid rotation. Changed from UI.
    var gridRotation = Float(0.0)

    /// The grid size. Changed from UI.
    var gridSize = CGFloat(0.0)

    /// Whether a vertex or more got dragged
    private var vertexDragged = false

    var selectedVertexIndices = Set<Int>()

    init(wad: Wad, lumpIndex: Int) {
        func loadItems<T: MapItem>(_ type: LumpOffset) -> [T] {
            let data = wad.lumps[lumpIndex + type.rawValue].data
            var list: [T] = []
            let recordSize = Level.lumpMap[type]!.recordSize
            for i in stride(from: 0, to: data.count, by: recordSize) {
                let slice = data[i ..< i + recordSize]
                list.append(T(data: Array(slice)))
            }
            return list
        }

        self.name = wad.lumps[lumpIndex].name

        self.things = loadItems(.things)
        self.linedefs = loadItems(.linedefs)
        self.sidedefs = loadItems(.sidedefs)
        self.vertices = loadItems(.vertices)
        self.segs = loadItems(.segs)
        self.subsectors = loadItems(.subsectors)
        self.nodes = loadItems(.nodes)
        self.sectors = loadItems(.sectors)

        self.reject = wad.lumps[lumpIndex + LumpOffset.reject.rawValue].data
        self.blockmap = []
        self.loadBlockmap(wad.lumps[lumpIndex + LumpOffset.blockmap.rawValue].data)

        postprocess()
    }

    fileprivate func loadBlockmap(_ blockmapData: [UInt8]) {
        self.blockmap = []
        let recordSize = Level.lumpMap[.blockmap]!.recordSize
        for i in stride(from: 0, to: blockmapData.count, by: recordSize) {
            self.blockmap.append(intFromInt16(blockmapData, loc: i))
        }
    }

    fileprivate func postprocess() {
        for line in linedefs {
            if line.v1 < 0 || line.v1 >= vertices.count || line.v2 < 0 || line.v2 >= vertices.count {
                continue
            }
            vertices[line.v1].degree += 1
            vertices[line.v2].degree += 1
        }
    }

    //==========================================================================
    //
    // USER ACTIONS
    //

    ///
    /// Finds the nearest vertex to a point, within a radius
    ///
    private func findNearestVertex(position: NSPoint, radius: CGFloat) -> Int? {
        var minDistance = CGFloat.greatestFiniteMagnitude
        var nearestVertex: Int? = nil
        var index = -1
        for vertex in vertices {
            index += 1
            let vertexPosition = NSPoint(x: vertex.x, y: vertex.y)
            let distance = position.distance(point: vertexPosition)
            if distance < radius && distance < minDistance {
                minDistance = distance
                nearestVertex = index
            }
        }
        return nearestVertex
    }

    ///
    /// Gets a vertex if the index is valid
    ///
    private func getVertex(index: Int?) -> Vertex? {
        if let ind = index {
            if ind >= 0 && ind < vertices.count {
                return vertices[ind]
            }
        }
        return nil
    }

    ///
    /// Highlights the vertex closest to a point, within a radius.
    /// Returns true if the highlighted vertex has changed.
    /// Can return "nothing"
    ///
    func highlightVertex(position: NSPoint, radius: CGFloat) -> Bool {
        let oldHighlightedVertexIndex = highlightedVertexIndex
        highlightedVertexIndex = findNearestVertex(position: position, radius: radius)
        return highlightedVertexIndex != oldHighlightedVertexIndex
    }

    ///
    /// Marks a vertex which has been started clicking.
    ///
    func clickDownVertex(position: NSPoint) {
        clickedDownVertexIndex = highlightedVertexIndex
        vertexDragged = false
        if let index = clickedDownVertexIndex {
            if index >= 0 && index < vertices.count {
                let vertex = vertices[index]
                clickedDownOffset = NSSize(width: position.x - CGFloat(vertex.x),
                                           height: position.y - CGFloat(vertex.y))
            }
        }
    }

    ///
    /// Drags vertices to a new position. Returns true if the view should be
    /// updated.
    ///
    func dragVertices(position: NSPoint) -> Bool {
        guard let clickedDownVertex = self.getVertex(index: self.clickedDownVertexIndex) else {
            return false
        }
        var actualPosition = position - self.clickedDownOffset

        if self.gridSize != 0 {
            if Int(round(self.gridRotation)) % 90 != 0 {
                actualPosition = actualPosition.rotated(self.gridRotation)
                actualPosition.x = round(actualPosition.x / self.gridSize) * self.gridSize
                actualPosition.y = round(actualPosition.y / self.gridSize) * self.gridSize
                actualPosition = actualPosition.rotated(-self.gridRotation)
            } else {
                actualPosition.x = round(actualPosition.x / self.gridSize) * self.gridSize
                actualPosition.y = round(actualPosition.y / self.gridSize) * self.gridSize
            }
        }

        let oldPositionX = clickedDownVertex.x
        let oldPositionY = clickedDownVertex.y

        clickedDownVertex.x = Int(round(actualPosition.x))
        clickedDownVertex.y = Int(round(actualPosition.y))

        if clickedDownVertex.x != oldPositionX || clickedDownVertex.y != oldPositionY {
            vertexDragged = true
            for index in selectedVertexIndices {
                if index == clickedDownVertexIndex {
                    continue
                }
                guard let vertex = getVertex(index: index) else {
                    continue
                }
                vertex.x += clickedDownVertex.x - oldPositionX
                vertex.y += clickedDownVertex.y - oldPositionY
            }
            return true
        }

        return false
    }

    func clickUpVertex() -> Bool {
        guard let clickedDownVertexIndex = self.clickedDownVertexIndex else {
            return false
        }
        if vertexDragged {
            return false
        }
        if selectedVertexIndices.contains(clickedDownVertexIndex) {
            selectedVertexIndices.remove(clickedDownVertexIndex)
            return true
        }

        selectedVertexIndices.insert(clickedDownVertexIndex)
        print("Size is \(selectedVertexIndices.count)")
        return true
    }
}

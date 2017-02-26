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

private protocol MapItem {
    init(data: [UInt8])
}

///
/// Level processed data
///
class Level
{
    /// Load exception
    enum LoadError: Error
    {
        case info(text: String)
    }

    /// This will allow both getting the lump name and lump index
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

    /// Lump load info
    struct LumpDefinition {
        let name: String
        let recordSize: Int
    }

    /// Maps a lump offset to its record definition
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

    /// Map thing
    final class Thing: MapItem {
        var x = 0       // coordinate
        var y = 0       // coordinate
        var angle = 0   // angle
        var type = 0    // doomednum
        var flags = 0   // spawn options

        init(data: [UInt8]) {
            DataReader(data).short(&x).short(&y).short(&angle).short(&type).short(&flags)
        }
    }

    /// Map linedef
    final class Linedef: MapItem {
        var v1 = 0      // vertex index
        var v2 = 0      // vertex index
        var flags = 0   // linedef bits
        var special = 0 // linedef trigger special
        var tag = 0     // linedef trigger tag
        var s1 = 0      // side index
        var s2 = 0      // side index

        init(data: [UInt8]) {
            DataReader(data).short(&v1).short(&v2).short(&flags).short(&special).short(&tag).short(&s1).short(&s2)
        }
    }

    /// Map sidedef
    final class Sidedef: MapItem {
        var xOffset = 0             // x offset
        var yOffset = 0             // y offset
        var upper: [UInt8] = []     // upper texture
        var lower: [UInt8] = []     // lower texture
        var middle: [UInt8] = []    // middle texture
        var sector = 0              // sector reference

        init(data: [UInt8]) {
            DataReader(data).short(&xOffset).short(&yOffset).lumpName(&upper).lumpName(&lower).lumpName(&middle).short(&sector)
        }
    }

    /// Map vertex
    final class Vertex: MapItem, Hashable {
        var x = 0       // coordinate
        var y = 0       // coordinate

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

    /// BSP segment
    final class Seg: MapItem {
        var v1 = 0      // vertex one
        var v2 = 0      // vertex two
        var angle = 0   // direction angle (unused?)
        var line = 0    // source linedef
        var dir = 0     // whether it's in the same direction or not
        var offset = 0  // offset along linedef

        init(data: [UInt8]) {
            DataReader(data).short(&v1).short(&v2).short(&angle).short(&line).short(&dir).short(&offset)
        }
    }

    /// BSP subsector
    final class Subsector: MapItem {
        var segCount = 0    // number of segs
        var firstSeg = 0    // first seg

        init(data: [UInt8]) {
            DataReader(data).short(&segCount).short(&firstSeg)
        }
    }

    /// BSP split
    final class Node: MapItem {
        var x0 = 0  // split start position
        var y0 = 0  // split start position
        var dx = 0  // split move to end
        var dy = 0  // split move to end
        var rightBox = (top:0, bottom:0, left:0, right:0)   // right bounding box
        var leftBox = (top:0, bottom:0, left:0, right:0)    // left bounding box
        var rightChild = 0  // right node or subsector
        var leftChild = 0   // left node or subsector

        init(data: [UInt8]) {
            DataReader(data).short(&x0).short(&y0).short(&dx).short(&dy)
                .short(&rightBox.top).short(&rightBox.bottom).short(&rightBox.left).short(&rightBox.right)
                .short(&leftBox.top).short(&leftBox.bottom).short(&leftBox.left).short(&leftBox.right)
                .short(&rightChild).short(&leftChild)
        }
    }

    /// Map sector
    final class Sector: MapItem {
        var floorheight = 0         // floor height
        var ceilingheight = 0       // ceiling height
        var floor: [UInt8] = []     // floor
        var ceiling: [UInt8] = []   // ceiling
        var light = 0               // light level
        var special = 0             // sector special
        var tag = 0                 // sector trigger tag

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

    /// The undo manager specific to this level
    let undo = UndoManager()
    weak var document: Document?

    func runUndo() {
        if undo.canUndo {
            undo.undo()
            document?.updateChangeCount(.changeUndone)
        }
    }
    func runRedo() {
        if undo.canRedo {
            undo.redo()
            document?.updateChangeCount(.changeRedone)
        }
    }
    func canUndo() -> Bool {
        return undo.canUndo
    }
    func canRedo() -> Bool {
        return undo.canRedo
    }
    func updateView() {
        self.document?.updateView()
    }
    func markChange() {
        self.undo.endUndoGrouping()
        document?.updateChangeCount(.changeDone)
    }

    private(set) var verticesDirty = false  // update VERTEXES lump
    /// Must be called when saving
    func cleanDirty() {
        verticesDirty = false
    }

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
    /// Vertex movement operation
    ///
    private func moveVertices(positions: [Int: NSPoint]) {
        var currentPositions: [Int: NSPoint] = [:]
        for (index, point) in positions {
            if let vertex = getVertex(index: index) {
                currentPositions[index] = NSPoint(x: vertex.x, y: vertex.y)
                vertex.x = Int(round(point.x))
                vertex.y = Int(round(point.y))
            }
        }
        self.updateView()
        self.undo.registerUndo {
            self.moveVertices(positions: currentPositions)
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

        var moveList: [Int: NSPoint] = [self.clickedDownVertexIndex!: NSPoint(x: oldPositionX, y: oldPositionY)]

        clickedDownVertex.x = Int(round(actualPosition.x))
        clickedDownVertex.y = Int(round(actualPosition.y))

        if clickedDownVertex.x != oldPositionX || clickedDownVertex.y != oldPositionY {
            if !vertexDragged {
                vertexDragged = true
                self.undo.beginUndoGrouping()   // prepare to start undoing
            }
            for index in selectedVertexIndices {
                if index == clickedDownVertexIndex {
                    continue
                }
                guard let vertex = getVertex(index: index) else {
                    continue
                }
                moveList[index] = NSPoint(x: vertex.x, y: vertex.y)
                vertex.x += clickedDownVertex.x - oldPositionX
                vertex.y += clickedDownVertex.y - oldPositionY
            }
            verticesDirty = true
            self.undo.registerUndo {
                self.moveVertices(positions: moveList)
            }
            return true
        }

        return false
    }

    ///
    /// When a vertex has been unclicked
    ///
    func clickUpVertex() -> Bool {
        guard let clickedDownVertexIndex = self.clickedDownVertexIndex else {
            return false
        }

        if vertexDragged {
            self.markChange()
            return false
        }
        if selectedVertexIndices.contains(clickedDownVertexIndex) {
            selectedVertexIndices.remove(clickedDownVertexIndex)
            return true
        }

        selectedVertexIndices.insert(clickedDownVertexIndex)
        return true
    }

    ///
    /// Selects all vertices
    ///
    func selectAllVertices() -> Bool {
        for i in 0..<vertices.count {
            selectedVertexIndices.insert(i)
        }
        return true
    }

    ///
    /// Deselects all
    ///
    func clearSelection() -> Bool {
        selectedVertexIndices = []
        return true
    }

    func boxSelect(startPos: NSPoint, endPos: NSPoint) {
        var index = -1
        let rotatedStart = startPos.rotated(self.gridRotation)
        let rotatedEnd = endPos.rotated(self.gridRotation)
        var rotatedRect = NSRect(origin: rotatedStart, size: CGSize())
        rotatedRect.pointAdd(rotatedEnd)
        for vertex in vertices {
            index += 1
            var rotated = NSPoint(x: vertex.x, y: vertex.y)
            rotated = rotated.rotated(self.gridRotation)
            if NSPointInRect(rotated, rotatedRect) {
                self.selectedVertexIndices.insert(index)
            }
        }
    }
}

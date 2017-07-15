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

protocol MapItem: class {
    init(data: [UInt8])
    func getData() -> [UInt8]
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

    enum Mode {
        case vertices
        case linedefs
        case sectors
        case things
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

    /// BSP segment
    final class Seg: MapItem {
        var v1 = 0      // vertex one
        var v2 = 0      // vertex two
        var angle = 0   // direction angle (unused?)
        var line = 0    // source linedef
        var dir = 0     // whether it's in the same direction or not
        var offset = 0  // offset along linedef

        init(data: [UInt8]) {
            DataReader(data).short(&v1).short(&v2).short(&angle).short(&line)
                .short(&dir).short(&offset)
        }

        func getData() -> [UInt8] {
            return DataWriter().short(v1).short(v2).short(angle).short(line)
                .short(dir).short(offset).data
        }
    }

    /// BSP subsector
    final class Subsector: MapItem {
        var segCount = 0    // number of segs
        var firstSeg = 0    // first seg

        init(data: [UInt8]) {
            DataReader(data).short(&segCount).short(&firstSeg)
        }

        func getData() -> [UInt8] {
            return DataWriter().short(segCount).short(firstSeg).data
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
                .short(&rightBox.top).short(&rightBox.bottom)
                .short(&rightBox.left).short(&rightBox.right)
                .short(&leftBox.top).short(&leftBox.bottom).short(&leftBox.left)
                .short(&leftBox.right)
                .short(&rightChild).short(&leftChild)
        }

        func getData() -> [UInt8] {
            return DataWriter().short(x0).short(y0).short(dx).short(dy)
                .short(rightBox.top).short(rightBox.bottom).short(rightBox.left)
                .short(rightBox.right).short(leftBox.top).short(leftBox.bottom)
                .short(leftBox.left).short(leftBox.right).short(rightChild)
                .short(leftChild).data
        }
    }

    fileprivate(set) var name: String

    fileprivate(set) var things: [Thing]
    private(set) var linedefs: [Linedef]
    fileprivate var sidedefs: [Sidedef]
    private(set) var vertices: [Vertex]
    fileprivate var segs: [Seg]
    fileprivate var subsectors: [Subsector]
    fileprivate var nodes: [Node]
    fileprivate var sectors: [Sector]
    fileprivate var reject: [UInt8]
    fileprivate var blockmap: [Int]

    private(set) var bspVertices: [Vertex]

    //
    // UNDO STUFF
    //

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

    //
    // MAP SAVING STUFF
    //

    private(set) var verticesDirty = false  // update VERTEXES lump
    private(set) var thingsDirty = false    // update THINGS lump
    /// Must be called when saving
    func cleanDirty() {
        verticesDirty = false
        thingsDirty = false
    }

    //
    // VERTEX USER INTERACTION
    //

    /// the vertex currently highlighted by the mouse
    private(set) weak var highlightedItem: MapItem?

    /// the vertex the user started holding down the mouse
    private(set) weak var clickedDownItem: MapItem?

    /// the map position the user started holding down the mouse
    private var clickedDownPosition = NSPoint()

    /// The grid rotation. Changed from UI.
    var gridRotation = Float(0.0)

    /// The grid size. Changed from UI.
    var gridSize = CGFloat(0.0)

    /// Selected vertices set
    let selectedDragItems: NSHashTable<DraggedItem> = NSHashTable.weakObjects()
    let selectedLinedefs: NSHashTable<Linedef> = NSHashTable.weakObjects()
    let selectedSectors: NSHashTable<Sector> = NSHashTable.weakObjects()

    /// Dragged vertices set
    let draggedItems: NSHashTable<DraggedItem> = NSHashTable.weakObjects()
    var draggingDone = false

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

        self.bspVertices = []

        self.reject = wad.lumps[lumpIndex + LumpOffset.reject.rawValue].data
        self.blockmap = []
        self.mode = Mode.vertices

        self.loadBlockmap(
            wad.lumps[lumpIndex + LumpOffset.blockmap.rawValue].data)
        checkBspVertices()
        setupLinedefs()
        setupSidedefs()
    }

    private func loadBlockmap(_ blockmapData: [UInt8]) {
        self.blockmap = []
        let recordSize = Level.lumpMap[.blockmap]!.recordSize
        for i in stride(from: 0, to: blockmapData.count, by: recordSize) {
            self.blockmap.append(intFromInt16(blockmapData, loc: i))
        }
    }

    private func checkBspVertices() {
        var visited = [Bool](repeating: false, count: vertices.count)
        func tryVisit(_ vertexIndex: Int) {
            if vertexIndex >= 0 && vertexIndex < visited.count {
                visited[vertexIndex] = true
            }
        }
        for line in linedefs {
            tryVisit(line.v1idx)
            tryVisit(line.v2idx)
        }
        var index = vertices.count
        for status in visited.reversed() {
            if status {
                break
            }
            index -= 1
        }
        if index < vertices.count {
            for i in index..<vertices.count {
                bspVertices.append(vertices[i])
            }
            vertices.removeLast(vertices.count - index)
        }
    }

    //
    // Validates linedefs
    //
    private func setupLinedefs() {
        for line in linedefs {
            line.setV1(list: vertices, index: line.v1idx)
            line.setV2(list: vertices, index: line.v2idx)
            line.setS1(list: sidedefs, index: line.s1idx)
            line.setS2(list: sidedefs, index: line.s2idx)
        }
    }

    //
    // Validates sidedefs
    //
    private func setupSidedefs() {
        for side in sidedefs {
            side.setSector(list: sectors, index: side.secnum)
        }
    }

    //==========================================================================
    //
    // Grid stuff
    //

    /// Snaps a point to grid
    func snapToGrid(_ point: NSPoint) -> NSPoint {
        if self.gridSize <= 0 {
            return point
        }
        var result = point
        if Int(round(self.gridRotation)) % 90 != 0 {
            result = result.rotated(self.gridRotation)
            result = result /• self.gridSize
            result = result.rotated(-self.gridRotation)
        } else {
            result = result /• self.gridSize
        }
        return result
    }

    //==========================================================================
    //
    // Mouse actions
    //

    ///
    /// Finds the nearest vertex to a point, within a radius
    ///
    private func findNearestItem(position: NSPoint, radius: CGFloat) ->
        MapItem?
    {
        var minDistance = CGFloat.greatestFiniteMagnitude
        var minRadius = CGFloat.greatestFiniteMagnitude
        var nearestItem: MapItem? = nil

        switch mode {
        case .vertices:
            for item in vertices {
                let vertexPosition = NSPoint(item: item)
                let distance = position <-> vertexPosition
                if distance < radius && distance < minDistance {
                    minDistance = distance
                    nearestItem = item
                }
            }
        case .things:
            for item in things {
                let vertexPosition = NSPoint(item: item)
                let thingRadius = CGFloat(item.info.radius)
                let distance = position <-> vertexPosition
                if distance < radius + thingRadius {
                    if distance < minDistance {
                        minDistance = distance
                        minRadius = thingRadius
                        nearestItem = item
                    } else if distance == minDistance && thingRadius < minRadius {
                        // equal position? Pick the thinnest one
                        minRadius = thingRadius
                        nearestItem = item
                    }
                }
            }
        case .linedefs:
            for linedef in linedefs {
                guard let v1 = linedef.v1 else {
                    continue
                }
                guard let v2 = linedef.v2 else {
                    continue
                }
                let p1 = NSPoint(item: v1)
                let p2 = NSPoint(item: v2)
                let box = NSRect(point1: p1, point2: p2)
                    .insetBy(dx: -radius, dy: -radius)
                if !NSPointInRect(position, box) {
                    continue
                }
                let distance = position.distanceToSegment(point1: p1, point2: p2)
                if distance < radius && distance < minDistance {
                    minDistance = distance
                    nearestItem = linedef
                }
            }
        case .sectors:
            for linedef in linedefs {
                guard let v1 = linedef.v1 else {
                    continue
                }
                guard let v2 = linedef.v2 else {
                    continue
                }
                let p1 = NSPoint(item: v1)
                let p2 = NSPoint(item: v2)
                let distance = position.distanceToSegment(point1: p1, point2: p2)
                if distance < minDistance {
                    minDistance = distance
                    let drill = (position - p1).drill(p2 - p1)
                    nearestItem = drill >= 0 ? linedef.frontsector : linedef.backsector
                }
            }
        }

        return nearestItem
    }

    ///
    /// Highlights the vertex closest to a point, within a radius.
    /// Returns true if the highlighted vertex has changed.
    /// Can return "nothing"
    ///
    func highlightClosest(position: NSPoint, radius: CGFloat) {
        let oldHighlightedItem = highlightedItem
        highlightedItem = findNearestItem(position: position, radius: radius)
        if highlightedItem !== oldHighlightedItem {
            document?.updateView()
        }
    }

    ///
    /// Vertex movement operation
    ///
    private func moveDragItems(positions: NSMapTable<DraggedItem, ObjWrap<NSPoint>>)
    {
        let currentPositions: NSMapTable<DraggedItem, ObjWrap<NSPoint>> =
            NSMapTable.weakToStrongObjects()
        let enumerator = positions.keyEnumerator()
        while let item = enumerator.nextObject() as? DraggedItem {
            currentPositions.setObject(ObjWrap(NSPoint(item: item)),
                                       forKey: item)
            let point = positions.object(forKey: item)!
            item.x = Int16(round(point.data.x))
            item.y = Int16(round(point.data.y))
            if item is Vertex {
                verticesDirty = true
            } else if item is Thing {
                thingsDirty = true
            }
        }
        self.updateView()
        self.undo.registerUndo {
            self.moveDragItems(positions: currentPositions)
        }
    }

    ///
    /// Marks a vertex which has been started clicking.
    ///
    func clickDownItem(position: NSPoint) {
        clickedDownItem = highlightedItem
        clickedDownPosition = position
    }

    ///
    /// Drags vertices to a new position. Returns true if the view should be
    /// updated.
    ///
    func dragItems(position: NSPoint) {
        guard let item = clickedDownItem else {
            return
        }
        if draggedItems.count <= 0 {
            switch mode {
            case .vertices, .things:
                if let item = item as? DraggedItem {
                    draggedItems.add(item)
                    draggedItems.union(selectedDragItems)
                }
            case .linedefs:
                if let linedef = item as? Linedef {
                    addToHashTable(draggedItems, array: linedef.vertices)
                    let enumerator = selectedLinedefs.objectEnumerator()
                    while let otherLine = enumerator.nextObject() as? Linedef {
                        addToHashTable(draggedItems, array: otherLine.vertices)
                    }
                }
            case .sectors:
                if let sector = item as? Sector {
                    addToHashTable(draggedItems, fromTable: sector.obtainVertices())
                    forEach(table: selectedSectors) { (otherSector) -> Bool in
                        addToHashTable(draggedItems, fromTable: otherSector.obtainVertices())
                        return true
                    }
                }
            }
        }

        forEach(table: draggedItems) { (item) -> Bool in
            let destination: NSPoint
            if mode == .vertices || mode == .things {
                guard let clickedItem = clickedDownItem as? DraggedItem else {
                    return false
                }
                let clickedPoint = NSPoint(item: clickedItem)
                let delta = clickedDownPosition - clickedPoint
                destination = snapToGrid(position - delta) + NSPoint(item: item) - clickedPoint
            } else {
                let delta = snapToGrid(position - clickedDownPosition)
                destination = NSPoint(item: item) + delta
            }
            if item.setDragging(point: destination) {
                draggingDone = true
                document?.updateView()
            }
            return true
        }
    }

    ///
    /// When a vertex has been unclicked
    ///
    func clickUpItem() {
        guard let clickedDownItem = self.clickedDownItem else {
            return
        }
        defer {
            draggingDone = false
            draggedItems.removeAllObjects()
            self.clickedDownItem = nil
        }

        if draggedItems.count > 0 && draggingDone {
            let positions = NSMapTable<DraggedItem, ObjWrap<NSPoint>>
                .weakToStrongObjects()
            var changed = false

            let enumerator = draggedItems.objectEnumerator()
            while let item = enumerator.nextObject() as? DraggedItem {
                let wrap = ObjWrap(NSPoint(x: Int(item.apparentX),
                                           y: Int(item.apparentY)))
                positions.setObject(wrap, forKey: item)

                if item.apparentX != item.x || item.apparentY != item.y {
                    changed = true
                }
                item.endDragging()
            }
            draggedItems.removeAllObjects()

            if changed {
                moveDragItems(positions: positions)
                document?.updateChangeCount(.changeDone)
            }
            return
        }

        switch mode {
        case .vertices, .things:
            if let item = clickedDownItem as? DraggedItem {
                toggleHashTable(selectedDragItems, object: item)
            }
        case .linedefs:
            if let linedef = clickedDownItem as? Linedef {
                toggleHashTable(selectedLinedefs, object: linedef)
            }
        case .sectors:
            if let sector = clickedDownItem as? Sector {
                toggleHashTable(selectedSectors, object: sector)
            }
        }
        document?.updateView()
    }

    //==========================================================================
    //
    // Object selection
    //

    ///
    /// Selects all vertices
    ///
    func selectAll() {
        switch mode {
        case .vertices:
            addToHashTable(selectedDragItems, array: vertices)
        case .things:
            addToHashTable(selectedDragItems, array: things)
        case .linedefs:
            addToHashTable(selectedLinedefs, array: linedefs)
        case .sectors:
            addToHashTable(selectedSectors, array: sectors)
        }
        document?.updateView()
    }

    ///
    /// Deselects all
    ///
    func clearSelection() {
        switch mode {
        case .vertices, .things:
            selectedDragItems.removeAllObjects()
        case .linedefs:
            selectedLinedefs.removeAllObjects()
        case .sectors:
            selectedSectors.removeAllObjects()
        }
        document?.updateView()
    }

    ///
    /// Performs box selection
    ///
    func boxSelect(startPos: NSPoint, endPos: NSPoint) {
        let rotatedRect = NSRect(point1: startPos.rotated(gridRotation),
                                 point2: endPos.rotated(gridRotation))
        var added = false
        switch mode {
        case .vertices:
            for vertex in vertices {
                let rotated = NSPoint(item: vertex).rotated(self.gridRotation)
                if NSPointInRect(rotated, rotatedRect) {
                    self.selectedDragItems.add(vertex)
                    added = true
                }
            }
        case .things:
            for thing in things {
                // pick each of the four corners
                let center = NSPoint(item: thing)
                let rad = thing.info.radius
                let points = [center + NSPoint(x: -rad, y: -rad),
                              center + NSPoint(x: rad, y: -rad),
                              center + NSPoint(x: rad, y: rad),
                              center + NSPoint(x: -rad, y: rad)]
                for point in points {
                    if NSPointInRect(point.rotated(self.gridRotation), rotatedRect)
                    {
                        self.selectedDragItems.add(thing)
                        added = true
                        break
                    }
                }
            }
        case .linedefs:
            for linedef in linedefs {
                guard let v1 = linedef.v1 else {
                    continue
                }
                guard let v2 = linedef.v2 else {
                    continue
                }
                let rp1 = NSPoint(item: v1).rotated(self.gridRotation)
                let rp2 = NSPoint(item: v2).rotated(self.gridRotation)
                if Geom.lineClipsRect(rp1, rp2, rect: rotatedRect) {
                    self.selectedLinedefs.add(linedef)
                    added = true
                }
            }
        case .sectors:
            for linedef in linedefs {
                guard let v1 = linedef.v1 else {
                    continue
                }
                guard let v2 = linedef.v2 else {
                    continue
                }
                let rp1 = NSPoint(item: v1).rotated(self.gridRotation)
                let rp2 = NSPoint(item: v2).rotated(self.gridRotation)
                if Geom.lineClipsRect(rp1, rp2, rect: rotatedRect) {
                    if let sector = linedef.frontsector {
                        selectedSectors.add(sector)
                    }
                    if let sector = linedef.backsector {
                        selectedSectors.add(sector)
                    }
                    added = true
                }
            }
        }
        if added {
            document?.updateView()
        }
    }

    //==========================================================================
    //
    // Mode switching
    //

    ///
    /// When current mode changes, update the selected items list to the most
    /// appropriate
    ///
    private func updateSelectionList(oldMode: Mode, newMode: Mode) {
        if newMode == oldMode {
            return
        }
        switch oldMode {
        case .vertices:
            if newMode == .linedefs {
                for linedef in linedefs {
                    if selectedDragItems.contains(linedef.v1) &&
                        selectedDragItems.contains(linedef.v2)
                    {
                        selectedLinedefs.add(linedef)
                    }
                }
            } else if newMode == .sectors {
                for sector in sectors {
                    if sector.obtainVertices().isSubset(of: selectedDragItems) {
                        selectedSectors.add(sector)
                    }
                }
            } else if newMode == .things {
                // TODO: select all things in containing sectors
            }
            selectedDragItems.removeAllObjects()
        case .linedefs:
            if newMode == .vertices {
                let enumerator = selectedLinedefs.objectEnumerator()
                while let linedef = enumerator.nextObject() as? Linedef {
                    if linedef.v1 !== nil {
                        selectedDragItems.add(linedef.v1)
                    }
                    if linedef.v2 !== nil {
                        selectedDragItems.add(linedef.v2)
                    }
                }
            } else if newMode == .sectors {
                for sector in sectors {
                    if sector.obtainLinedefs().isSubset(of: selectedLinedefs) {
                        selectedSectors.add(sector)
                    }
                }
            } else if newMode == .things {
                // TODO: select all things in containing sectors
            }
            selectedLinedefs.removeAllObjects()
        case .sectors:
            if newMode == .vertices {
                let enumerator = selectedSectors.objectEnumerator()
                while let sector = enumerator.nextObject() as? Sector {
                    selectedDragItems.union(sector.obtainVertices())
                }
            } else if newMode == .linedefs {
                let enumerator = selectedSectors.objectEnumerator()
                while let sector = enumerator.nextObject() as? Sector {
                    selectedLinedefs.union(sector.obtainLinedefs())
                }
            } else if newMode == .things {
                // TODO: select all things in containing sectors
            }
            selectedSectors.removeAllObjects()
        case .things:
            // TODO: select sectors if all things are selected
            selectedDragItems.removeAllObjects()
        }
        document?.updateView()
    }

    var mode: Mode {
        willSet(newMode) {
            updateSelectionList(oldMode: mode, newMode: newMode)
        }
        didSet {
            document?.updateMode(mode)
        }
    }
}

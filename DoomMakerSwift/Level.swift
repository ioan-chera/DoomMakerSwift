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
    weak var document: Document?

    func runUndo() {
        if document?.undoManager?.canUndo == true {
            document?.undoManager?.undo()
        }
    }
    func runRedo() {
        if document?.undoManager?.canRedo == true {
            document?.undoManager?.redo()
        }
    }
    func canUndo() -> Bool {
        return document?.undoManager?.canUndo == true
    }
    func canRedo() -> Bool {
        return document?.undoManager?.canRedo == true
    }
    func updateView() {
        self.document?.updateView()
    }
    private var undo: UndoManager? {
        get {
            return document?.undoManager
        }
    }

    //
    // MAP SAVING STUFF
    //

    private(set) var linedefTracking = 0
    private(set) var sectorTracking = 0
    private(set) var sidedefTracking = 0
    private(set) var thingTracking = 0    // update THINGS lump
    private(set) var vertexTracking = 0  // update VERTEXES lump
    private(set) var nodeTracking = 0   // rebuild BSP

    private func updateDirty(_ value: inout Int) {
        if undo?.isUndoing == false {
            value += 1
        } else {
            value -= 1
        }
    }

    /// Must be called when saving
    func cleanDirty() {
        linedefTracking = 0
        sectorTracking = 0
        sidedefTracking = 0
        thingTracking = 0
        vertexTracking = 0
        nodeTracking = 0
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
        setupLinedefs()
        setupSidedefs()
        checkBspVertices()
    }

    private func loadBlockmap(_ blockmapData: [UInt8]) {
        self.blockmap = []
        let recordSize = Level.lumpMap[.blockmap]!.recordSize
        for i in stride(from: 0, to: blockmapData.count, by: recordSize) {
            self.blockmap.append(intFromInt16(blockmapData, loc: i))
        }
    }

    private func checkBspVertices() {
        var index = 0
        for vertex in vertices {
            if vertex.linedefs.count == 0 {
                bspVertices.append(vertex)
                vertices.remove(at: index)
                index -= 1
            }
            index += 1
        }
    }

    //
    // Validates linedefs
    //
    private func setupLinedefs() {
        for line in linedefs {
            line.v1 = safeArrayGet(vertices, index: line.v1idx)
            line.v2 = safeArrayGet(vertices, index: line.v2idx)
            line.s1 = safeArrayGet(sidedefs, index: line.s1idx)
            line.s2 = safeArrayGet(sidedefs, index: line.s2idx)
        }
    }

    //
    // Validates sidedefs
    //
    private func setupSidedefs() {
        for side in sidedefs {
            side.sector = safeArrayGet(sectors, index: side.secnum)
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

        var changeVertices = false
        var changeThings = false

        while let item = enumerator.nextObject() as? DraggedItem {
            currentPositions.setObject(ObjWrap(NSPoint(item: item)),
                                       forKey: item)
            let point = positions.object(forKey: item)!
            item.x = Int16(round(point.data.x))
            item.y = Int16(round(point.data.y))
            if item is Vertex {
                changeVertices = true
            } else if item is Thing {
                changeThings = true
            }
        }

        // Tracking vertex changes is more important, because of node-building
        // considerations
        if changeVertices {
            updateDirty(&vertexTracking)
            updateDirty(&nodeTracking)
        }
        if changeThings {
            updateDirty(&thingTracking)
        }

        self.updateView()
        self.document?.undoManager?.registerUndo {
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
    // Complex operations
    //

    ///
    /// Merge a vertex into another vertex, by transferring properties
    ///
    private func merge(vertex v1: Vertex, into v2: Vertex) {
        // Locate all linedefs from v1 and reattach them

        var v1lines = [Linedef]()
        var v2lines = [Linedef]()

        // need to add them first to list, then transfer values
        forEach(table: v1.linedefs) { (line) -> Bool in
            if line.v1 === v1 {
                v1lines.append(line)
            } else if line.v2 === v1 {
                v2lines.append(line)
            }
            return true
        }

        for line in v1lines {
            line.v1 = v2
        }
        for line in v2lines {
            line.v2 = v2
        }
        removeFrom(array: &vertices, item: v1)
    }

    ///
    /// Adds a thing
    ///
    private func add(thing: Thing, index: Int) {
        things.insert(thing, at: index)
        self.document?.undoManager?.registerUndo {
            self.delete(thing: thing)
        }
        updateDirty(&thingTracking)
        updateView()
    }

    ///
    /// Adds a new linedef
    ///
    private func add(linedef: Linedef, index: Int, v1: Vertex?, v2: Vertex?,
                     s1: Sidedef?, s2: Sidedef?)
    {
        linedefs.insert(linedef, at: index)
        linedef.s1 = s1
        linedef.s2 = s2
        linedef.v1 = v1
        linedef.v2 = v2
        document?.undoManager?.registerUndo {
            self.delete(linedef: linedef)
        }
        updateDirty(&linedefTracking)
        updateDirty(&nodeTracking)
        updateView()
    }

    ///
    /// Adds a deleted sidedef
    ///
    private func add(sidedef: Sidedef, index: Int, sector: Sector?,
                     s1lines: NSHashTable<Linedef>,
                     s2lines: NSHashTable<Linedef>)
    {
        sidedefs.insert(sidedef, at: index)
        var enumerator = s1lines.objectEnumerator()
        while let linedef = enumerator.nextObject() as? Linedef {
            linedef.s1 = sidedef
        }
        enumerator = s2lines.objectEnumerator()
        while let linedef = enumerator.nextObject() as? Linedef {
            linedef.s2 = sidedef
        }
        sidedef.sector = sector
        document?.undoManager?.registerUndo {
            self.delete(sidedef: sidedef)
        }

        updateDirty(&sidedefTracking)
        updateDirty(&nodeTracking)
        updateView()
    }

    ///
    /// Add back a vertex
    ///
    private func add(vertex: Vertex, index: Int) {
        vertices.insert(vertex, at: index)
        document?.undoManager?.registerUndo {
            self.delete(vertex: vertex)
        }
        updateDirty(&vertexTracking)
        updateDirty(&nodeTracking)
        updateView()
    }

    ///
    /// Add back a sector
    ///
    private func add(sector: Sector, index: Int) {
        sectors.insert(sector, at: index)
        document?.undoManager?.registerUndo {
            self.delete(sector: sector)
        }
        updateDirty(&sectorTracking)
        updateDirty(&nodeTracking)
        updateView()
    }

    ///
    /// Deletes a thing and provides undo
    ///
    private func delete(thing: Thing) {
        guard let index = indexOf(array: things, item: thing) else {
            return
        }
        things.remove(at: index)
        self.document?.undoManager?.registerUndo {
            self.add(thing: thing, index: index)
        }
        updateDirty(&thingTracking)
        updateView()
    }

    ///
    /// Deletes a sector
    ///
    private func delete(sector: Sector) {
        guard let index = indexOf(array: sectors, item: sector) else {
            return
        }
        if sector.sidedefs.count == 0 {
            sectors.remove(at: index)
            document?.undoManager?.registerUndo {
                self.add(sector: sector, index: index)
            }

            updateDirty(&sectorTracking)
            updateDirty(&nodeTracking)
            updateView()
            return
        }
        while let sidedef = sector.sidedefs.anyObject {
            delete(sidedef: sidedef)
        }

        updateView()
        return
    }

    ///
    /// Deletes a sidedef
    ///
    private func delete(sidedef: Sidedef) {
        guard let index = indexOf(array: sidedefs, item: sidedef) else {
            return
        }
        let sector = sidedef.sector
        let s1lines = NSHashTable<Linedef>.weakObjects()
        let s2lines = NSHashTable<Linedef>.weakObjects()
        sidedef.sector = nil

        while let linedef = sidedef.linedefs.anyObject {
            if linedef.s1 === sidedef || linedef.s2 === sidedef {
                setLineFlags(linedef: linedef, flags: (linedef.flags | LineFlagImpassable) & ~LineFlagTwoSided)
            }
            if linedef.s1 === sidedef {
                s1lines.add(linedef)
                linedef.s1 = nil
            }
            if linedef.s2 === sidedef {
                s2lines.add(linedef)
                linedef.s2 = nil
            }
        }

        sidedefs.remove(at: index)
        document?.undoManager?.registerUndo {
            self.add(sidedef: sidedef, index: index, sector: sector,
                     s1lines: s1lines, s2lines: s2lines)
        }
        if sector !== nil && sector!.sidedefs.count == 0 {
            delete(sector: sector!)
        }

        // Make sure to flip lines whose first side is deleted. Or just delete
        // them if they're fully emptied
        let linesToDelete = NSHashTable<Linedef>.weakObjects()
        forEach(table: s1lines) { (line) -> Bool in
            if line.s2 === nil {
                // Totally cleared
                linesToDelete.add(line)
            } else {
                self.flip(linedef: line)
            }
            return true
        }

        // Also delete any other totally cleared lines
        forEach(table: s2lines) { (line) -> Bool in
            if line.s1 === nil {
                linesToDelete.add(line)
            }
            return true
        }

        while let linedef = linesToDelete.anyObject {
            delete(linedef: linedef)
            linesToDelete.remove(linedef)
        }

        updateDirty(&sidedefTracking)
        updateDirty(&nodeTracking)
        updateView()
    }

    ///
    /// Deletes a linedef
    ///
    private func delete(linedef: Linedef, keepVertices: Bool = false) {
        guard let index = indexOf(array: linedefs, item: linedef) else {
            return
        }
        // first unreference sidedefs
        let s1 = linedef.s1
        let s2 = linedef.s2
        let v1 = linedef.v1
        let v2 = linedef.v2
        linedef.s1 = nil
        linedef.s2 = nil
        linedef.v1 = nil
        linedef.v2 = nil
        // Check if sidedefs are orphaned. Then delete them
        linedefs.remove(at: index)
        document?.undoManager?.registerUndo {
            self.add(linedef: linedef, index: index, v1: v1, v2: v2,
                     s1: s1, s2: s2)
        }
        if !keepVertices {
            if v1 !== nil && v1!.linedefs.count == 0 {
                delete(vertex: v1!)
            }
            if v2 !== nil && v2!.linedefs.count == 0 {
                delete(vertex: v2!)
            }
        }
        if s1 !== nil && s1!.linedefs.count == 0 {
            delete(sidedef: s1!)
        }
        if s2 !== nil && s2!.linedefs.count == 0 {
            delete(sidedef: s2!)
        }

        updateDirty(&linedefTracking)
        updateDirty(&nodeTracking)
        updateView()
    }

    ///
    /// Deletes a vertex
    ///
    private func delete(vertex: Vertex) {
        guard let index = indexOf(array: vertices, item: vertex) else {
            return
        }

        // Delete vertex if it's isolated
        if vertex.linedefs.count == 0 {
            vertices.remove(at: index)
            document?.undoManager?.registerUndo {
                self.add(vertex: vertex, index: index)
            }
            updateDirty(&vertexTracking)
            updateDirty(&nodeTracking)
            updateView()
            return
        }

        // If it's connected to two linedefs, then delete the shorter one and
        // join the longer one with the other vertex
        if vertex.linedefs.count == 2 {

            func changeVertex(linedef: Linedef, which: Int, target: Vertex) {
                let original: Vertex
                if which == 1 {
                    original = linedef.v1!
                    linedef.v1 = target
                } else {
                    original = linedef.v2!
                    linedef.v2 = target
                }
                self.document?.undoManager?.registerUndo {
                    changeVertex(linedef: linedef, which: which, target: original)
                }
                self.updateDirty(&linedefTracking)
            }

            // Pick the longer linedef
            let enumerator = vertex.linedefs.objectEnumerator()
            let line1 = enumerator.nextObject() as! Linedef
            let length1 = line1.length()
            let line2 = enumerator.nextObject() as! Linedef
            let length2 = line2.length()
            let lineToDelete = length1 < length2 ? line1 : line2
            let lineToKeep = length1 < length2 ? line2 : line1

            // Keep reference to other vertex
            let otherVertex = lineToDelete.v1 === vertex ? lineToDelete.v2 :
                lineToDelete.v1

            let originVertex = lineToKeep.v1 === vertex ? lineToKeep.v2 :
                lineToKeep.v1

            // If the "shorter" linedef is actually a degenerate one without a
            // vertex, then just fall through to normal deletion of adjacent
            // lines
            // Also avoid degenerating triangle sectors
            if otherVertex !== nil && originVertex !== nil &&
                !originVertex!.linedefs.intersects(otherVertex!.linedefs)
            {
                // Delete the linedef
                delete(linedef: lineToDelete, keepVertices: true)

                let vindex: Int
                if lineToKeep.v1 === vertex {
                    vindex = 1
                } else {
                    vindex = 2
                }

                changeVertex(linedef: lineToKeep, which: vindex, target: otherVertex!)

                vertices.remove(at: index)
                document?.undoManager?.registerUndo {
                    self.add(vertex: vertex, index: index)
                }

                updateDirty(&vertexTracking)
                updateDirty(&nodeTracking)
                updateView()
                return
            }
        }

        // Otherwise delete the connected linedefs
        while let linedef = vertex.linedefs.anyObject {
            delete(linedef: linedef)
        }

        updateDirty(&vertexTracking)
        updateDirty(&nodeTracking)
        updateView()
    }

    ///
    /// Flip linedefs
    ///
    func flip(linedef: Linedef) {
        guard let v1 = linedef.v1 else {
            return
        }
        guard let v2 = linedef.v2 else {
            return
        }
        // Can't simply swap, because self-looping lines are illegal
        linedef.v1 = nil
        linedef.v2 = nil
        linedef.v1 = v2
        linedef.v2 = v1
        let s1 = linedef.s1
        let s2 = linedef.s2
        linedef.s1 = nil
        linedef.s2 = nil
        linedef.s1 = s2
        linedef.s2 = s1
        document?.undoManager?.registerUndo {
            self.flip(linedef: linedef)
        }

        updateDirty(&linedefTracking)
        updateDirty(&nodeTracking)
        updateView()
    }

    ///
    /// Set linedef flags
    ///
    func setLineFlags(linedef: Linedef, flags: Int) {
        let curFlags = linedef.flags
        linedef.flags = flags
        undo?.registerUndo {
            self.setLineFlags(linedef: linedef, flags: curFlags)
        }
        updateDirty(&linedefTracking)
        updateView()
    }

    //==========================================================================
    //
    // Menu results
    //
    func deleteSelection() {
        switch mode {
        case .things:
            if selectedDragItems.count > 0 {
                let enumerator = selectedDragItems.objectEnumerator()
                while let thing = enumerator.nextObject() as? Thing {
                    delete(thing: thing)
                }
            } else if let thing = highlightedItem as? Thing {
                delete(thing: thing)
            }
        case .vertices:
            if selectedDragItems.count > 0 {
                let enumerator = selectedDragItems.objectEnumerator()
                while let vertex = enumerator.nextObject() as? Vertex {
                    delete(vertex: vertex)
                }
            } else if let vertex = highlightedItem as? Vertex {
                delete(vertex: vertex)
            }
        case .linedefs:
            if selectedLinedefs.count > 0 {
                let enumerator = selectedLinedefs.objectEnumerator()
                while let linedef = enumerator.nextObject() as? Linedef {
                    delete(linedef: linedef)
                }
            } else if let linedef = highlightedItem as? Linedef {
                delete(linedef: linedef)
            }
        case .sectors:
            if selectedSectors.count > 0 {
                let enumerator = selectedSectors.objectEnumerator()
                while let sector = enumerator.nextObject() as? Sector {
                    delete(sector: sector)
                }
            } else if let sector = highlightedItem as? Sector {
                delete(sector: sector)
            }
        }
        clearSelection()
    }

    func canDeleteSelection() -> Bool {
        switch mode {
        case .things, .vertices:
            return selectedDragItems.count > 0 || highlightedItem !== nil
        case .linedefs:
            return selectedLinedefs.count > 0 || highlightedItem as? Linedef !== nil
        case .sectors:
            return selectedSectors.count > 0 || highlightedItem as? Sector !== nil
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

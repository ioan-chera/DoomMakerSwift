//
//  MapView.swift
//  DoomMakerSwift
//
//  Created by ioan on 15.07.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Cocoa

protocol MapViewDelegate: class {
    func mapViewGridSizeUpdated()
    func mapViewScaleUpdated()
    func mapViewPositionUpdated(_ position: NSPoint)
    func mapViewRotationUpdated()
}

class MapView: NSView {
    weak var delegate: MapViewDelegate? {
        didSet {
            delegate?.mapViewGridSizeUpdated()
            delegate?.mapViewScaleUpdated()
            delegate?.mapViewPositionUpdated(NSPoint())
            delegate?.mapViewRotationUpdated()
        }
    }

    fileprivate var translate = NSPoint()
    var scale = CGFloat(1) {
        didSet {
            delegate?.mapViewScaleUpdated()
        }
    }
    var rotate = Float(0) {
        didSet {
            level?.gridRotation = self.rotate
        }
    }
    fileprivate var rotatingGesture = false

    fileprivate var trackingArea: NSTrackingArea?

    private var mouseViewPos = NSPoint()
    private var mouseGamePos = NSPoint() {
        didSet {
            delegate?.mapViewPositionUpdated(mouseGamePos)
        }
    }

    private var dragViewStart = NSPoint()
    private var dragSelect = false

    var gridSize = Const.gridDefault {
        didSet {
            level?.gridSize = CGFloat(self.gridSize)
            delegate?.mapViewGridSizeUpdated()
        }
    }

    struct Const {
        static let clickRange = CGFloat(16)
        static let fps = 120.0
        fileprivate static let gridWidth = CGFloat(1) / (NSScreen.main()?.backingScaleFactor ?? 1)
        fileprivate static let gridColor = NSColor(red: 0, green: CGFloat(0.5), blue: CGFloat(0.5), alpha: 1)
        fileprivate static let linedefWidth = CGFloat(1)
        fileprivate static let selectWidth = CGFloat(1.5)
        fileprivate static let vertexRadius = CGFloat(2)
        fileprivate static let movePeriod = 1.0 / 30
        fileprivate static let gridMin = 2
        static let gridDefault = 8
        fileprivate static let gridMax = 1024
        fileprivate static let scaleMin = CGFloat(0.1)
        fileprivate static let scaleMax = CGFloat(10)
        static let rotateSnapDegrees = Float(5)
        fileprivate static let zoomKeyAmount = CGFloat(0.25)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    fileprivate func commonInit() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.cgColor
        let area = NSTrackingArea(rect: self.bounds, options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved], owner: self, userInfo: nil)
        trackingArea = area
        self.addTrackingArea(area)
        self.acceptsTouchEvents = true
    }

    override func updateTrackingAreas() {
        guard var area = trackingArea else {
            return super.updateTrackingAreas()
        }
        removeTrackingArea(area)
        area = NSTrackingArea(rect: self.bounds, options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved], owner: self, userInfo: nil)
        trackingArea = area
        addTrackingArea(area)
    }

    weak var level: Level? {
        didSet {
            self.acceptsTouchEvents = true
            self.level?.gridSize = CGFloat(self.gridSize)
            self.level?.gridRotation = self.rotate
            self.setNeedsDisplay(self.bounds)
        }
    }

    fileprivate func drawGrid(_ dirtyRect: NSRect, context: CGContext) {

        let gridf = CGFloat(gridSize) * scale   // for casting's sake
        if gridf <= 2 {
            Const.gridColor.setFill()
            NSRectFill(dirtyRect)
            return
        }

        context.setLineWidth(Const.gridWidth)
        context.setStrokeColor(Const.gridColor.cgColor)

        let disp = translate - floor(translate / gridf) * gridf

        let minx = ceil(dirtyRect.origin.x / gridf) * gridf - gridf
        let maxx = floor(dirtyRect.origin.x + dirtyRect.size.width / gridf) * gridf + 2 * gridf
        let miny = ceil(dirtyRect.origin.y / gridf) * gridf - gridf
        let maxy = floor(dirtyRect.origin.y + dirtyRect.size.height / gridf) * gridf + 2 * gridf

        var p: NSPoint
        for x in stride(from: minx, through: maxx, by: gridf) {
            p = NSPoint(x: x, y: miny - gridf) + disp
            context.move(to: CGPoint(x: p.x, y: p.y))
            p = NSPoint(x: x, y: maxy + gridf) + disp
            context.addLine(to: CGPoint(x: p.x, y: p.y))
        }
        for y in stride(from: miny, through: maxy, by: gridf) {
            p = NSPoint(x: minx - gridf, y: y) + disp
            context.move(to: CGPoint(x: p.x, y: p.y))
            p = NSPoint(x: maxx, y: y) + disp
            context.addLine(to: CGPoint(x: p.x, y: p.y))
        }
        context.strokePath()
    }



    fileprivate func drawLines(_ dirtyRect: NSRect, context: CGContext) {
        func transformed(_ p: NSPoint) -> NSPoint {
            return p.rotated(rotate) * scale + translate
        }

        guard let level = self.level else {
            return
        }

        context.setLineWidth(Const.linedefWidth)
        for line in level.linedefs {
            if line.v1 < 0 || line.v1 >= level.vertices.count || line.v2 < 0 || line.v2 >= level.vertices.count || line.v1 == line.v2 {
                continue
            }
            let v1 = level.vertices[line.v1]
            let v2 = level.vertices[line.v2]
            let p1 = transformed(NSPoint(x: v1.x, y: v1.y))
            let p2 = transformed(NSPoint(x: v2.x, y: v2.y))

            if p1.x < dirtyRect.minX && p2.x < dirtyRect.minX ||
                p1.x >= dirtyRect.maxX && p2.x >= dirtyRect.maxX ||
                p1.y < dirtyRect.minY && p2.y < dirtyRect.minY ||
                p1.y >= dirtyRect.maxY && p2.y >= dirtyRect.maxY
            {
                continue
            }

//            if !Geom.lineClipsRect(p1, p2, rect: dirtyRect) {
//                continue
//            }

            if line.flags & 1 == 1 {
                context.setStrokeColor(NSColor.white.cgColor)
            } else {
                context.setStrokeColor(NSColor.gray.cgColor)
            }
            context.move(to: CGPoint(x: p1.x, y: p1.y))
            context.addLine(to: CGPoint(x: p2.x, y: p2.y))
            context.strokePath()
        }

        var index = -1
        for vertex in level.vertices {
            index += 1
            if vertex.degree == 0 {
                continue
            }
            let p = transformed(NSPoint(x: vertex.x, y: vertex.y))
            if !NSPointInRect(p, dirtyRect.insetBy(dx: -Const.vertexRadius, dy: -Const.vertexRadius)) {
                continue
            }

            if index == level.highlightedVertexIndex {
                context.setFillColor(NSColor.orange.cgColor)
            } else if level.selectedVertexIndices.contains(index) {
                context.setFillColor(NSColor.red.cgColor)
            } else {
                context.setFillColor(NSColor.green.cgColor)
            }

            context.fillEllipse(in: NSRect(x: p.x - Const.vertexRadius, y: p.y - Const.vertexRadius, width: Const.vertexRadius * 2, height: Const.vertexRadius * 2))
        }

//        let thingRadius = 16 * scale
//        let biggerRect = NSRectFromCGRect(CGRectInset(NSRectToCGRect(dirtyRect), -thingRadius, -thingRadius))
//        for thing in level.things {
//            let p = transformed(NSPoint(x: thing.x, y: thing.y))
//            if !NSPointInRect(p, biggerRect) {
//                continue
//            }
//            things.appendBezierPathWithOvalInRect(NSRect(x: p.x - thingRadius, y: p.y - thingRadius, width: 2 * thingRadius, height: 2 * thingRadius))
//        }
//
//        NSColor(red: 1, green: 0, blue: 0, alpha: 0.75).setFill()
//        things.fill()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current()?.cgContext else {
            return
        }

        drawGrid(dirtyRect, context: context)
        drawLines(dirtyRect, context: context)

        if dragSelect {
            let rect = CGRect(x: dragViewStart.x, y: dragViewStart.y,
                              width: mouseViewPos.x - dragViewStart.x, height: mouseViewPos.y - dragViewStart.y)

            context.setLineWidth(Const.selectWidth)
            context.setStrokeColor(NSColor.orange.cgColor)
            context.addRect(rect)
            context.strokePath()
        }
    }

    override var acceptsFirstResponder: Bool {
        get {
            return true
        }
    }

    ///
    /// Transforms cursor position to game position
    ///
    fileprivate func gamePos(_ cursorPos: NSPoint) -> NSPoint {
        return ((cursorPos - self.translate) / self.scale).rotated(-self.rotate)
    }

    fileprivate func setRotation(_ value: Float, cursorpos: NSPoint) {
        let center = gamePos(cursorpos)
        self.rotate = value
        if self.rotate > 180.0 {
            self.rotate -= 360.0
        } else if self.rotate <= -180.0 {
            self.rotate += 360.0
        }
        self.level?.gridRotation = self.rotate
        let center2 = gamePos(cursorpos)
        self.translate = self.translate + (center2 - center).rotated(self.rotate) * self.scale
        capTranslation()
        delegate?.mapViewRotationUpdated()
    }

    fileprivate func snapRotation(_ updateDisplay: Bool, cursorpos: NSPoint) {
        if self.rotatingGesture {
            self.setRotation(round(self.rotate / Const.rotateSnapDegrees) * Const.rotateSnapDegrees, cursorpos: cursorpos)
            self.rotatingGesture = false
            if updateDisplay {
                self.setNeedsDisplay(self.bounds)
            }
        }
    }

    //
    // Events
    //

    fileprivate func capTranslation() {
        if translate.x / scale > 32768 {
            translate.x = 32768 * scale
        }
        else if (translate.x - self.bounds.width) / scale < -32767 {
            translate.x = -32767 * scale + self.bounds.width
        }

        if translate.y / scale > 32768 {
            translate.y = 32768 * scale
        }
        else if (translate.y - self.bounds.height) / scale < -32767 {
            translate.y = -32767 * scale + self.bounds.height
        }
    }

    override func scrollWheel(with theEvent: NSEvent) {
        let pixelScale = NSScreen.main()?.backingScaleFactor ?? 1

        // TODO: add scaling and rotation with the mouse wheel

        if theEvent.modifierFlags.contains(.option) {
            // Negative means move map towards me
            let cursorpos = self.convert(theEvent.locationInWindow, from: nil)
            self.doMagnification(theEvent.scrollingDeltaY / 40, cursorpos: cursorpos)
            return
        }

        // TODO: also add hotkeys

        translate.x += theEvent.scrollingDeltaX * pixelScale
        translate.y -= theEvent.scrollingDeltaY * pixelScale

        capTranslation()

        // Also update position for the map
        mouseViewPos = self.convert(theEvent.locationInWindow, from: nil)
        mouseGamePos = gamePos(mouseViewPos)

        self.setNeedsDisplay(self.bounds)
    }

    ///
    /// Handles magnification
    ///
    fileprivate func doMagnification(_ amount: CGFloat, cursorpos: NSPoint) {
        if (amount > 0 && self.scale >= Const.scaleMax) ||
            (amount < 0 && self.scale <= Const.scaleMin)
        {
            return
        }

        self.snapRotation(false, cursorpos: cursorpos)

        let center = (cursorpos - self.translate) / self.scale
        self.scale *= 1 + amount
        if self.scale >= Const.scaleMax {
            self.scale = Const.scaleMax
        } else if self.scale <= Const.scaleMin {
            self.scale = Const.scaleMin
        }
        let center2 = (cursorpos - self.translate) / self.scale
        self.translate = self.translate + (center2 - center) * self.scale
        capTranslation()

        self.setNeedsDisplay(self.bounds)
    }

    override func magnify(with event: NSEvent) {
        let cursorpos = self.convert(event.locationInWindow, from: nil)
        self.doMagnification(event.magnification, cursorpos: cursorpos)
    }

    override func rotate(with event: NSEvent) {
        let cursorpos = self.convert(event.locationInWindow, from: nil)
        self.setRotation(self.rotate + event.rotation, cursorpos: cursorpos)
        self.rotatingGesture = true
        self.setNeedsDisplay(self.bounds)
    }

    override func touchesEnded(with event: NSEvent) {
        let cursorpos = self.convert(event.locationInWindow, from: nil)
        if event.touches(matching: .touching, in: nil).count == 1 {
            self.snapRotation(true, cursorpos: cursorpos)
        }
    }

    //==========================================================================
    //
    // User operations
    //

    ///
    /// Updates the mouse view and game positions
    ///
    private func updatePosition(event: NSEvent) {
        mouseViewPos = self.convert(event.locationInWindow, from: nil)
        mouseGamePos = gamePos(mouseViewPos)
    }

    override func mouseMoved(with theEvent: NSEvent) {
        guard let level = self.level else {
            return
        }
        updatePosition(event: theEvent)
        let gameClickRange = self.scale != 0 ? Const.clickRange / self.scale : Const.clickRange
        if level.highlightVertex(position: mouseGamePos, radius: gameClickRange) {
            self.setNeedsDisplay(self.bounds)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let level = self.level else {
            return
        }
        level.clickDownVertex(position: mouseGamePos)
        dragViewStart = mouseViewPos
    }

    override func mouseDragged(with event: NSEvent) {
        guard let level = self.level else {
            return
        }
        updatePosition(event: event)
        if level.clickedDownVertexIndex != nil {
            if level.dragVertices(position: mouseGamePos) {
                self.setNeedsDisplay(self.bounds)
            }
        } else {
            dragSelect = true
            self.setNeedsDisplay(self.bounds)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let level = self.level else {
            dragSelect = false
            return
        }
        if level.clickUpVertex() || dragSelect {
            if dragSelect {
                level.boxSelect(startPos: gamePos(self.dragViewStart), endPos: self.mouseGamePos)
                dragSelect = false
            }
            self.setNeedsDisplay(self.bounds)
        }
    }

//    override func mouseDown(with event: NSEvent) {
//        guard let level = self.level else {
//            return
//        }
//        level.selectedVertices = self.highlightedVertices
//
//        var a = NSRect(x: mouseViewPos.x, y: mouseViewPos.y, width: 0, height: 0)
//        a = a.insetBy(dx: -Const.clickRange - Const.vertexRadius, dy: -Const.clickRange - Const.vertexRadius)
//
//        self.setNeedsDisplay(self.bounds)
//
//        clickedStartGamePos = mouseGamePos
//        clickedVertex = closestVertex
//        if let cv = clickedVertex {
//            clickedStartVertexPos = NSPoint(x: cv.x, y: cv.y)
//        }
//    }
//
//    override func mouseUp(with event: NSEvent) {
//        clickedVertex = nil
//    }
//
//    override func mouseDragged(with event: NSEvent) {
//        guard let level = self.level else {
//            return
//        }
//        self.mouseMoved(with: event)
//        guard let clickedVertex = self.clickedVertex else {
//            return
//        }
//
//        var snappedPos = NSPoint(x: clickedStartVertexPos.x + mouseGamePos.x - clickedStartGamePos.x,
//                                 y: clickedStartVertexPos.y + mouseGamePos.y - clickedStartGamePos.y)
//        let gs = CGFloat(gridSize)
//        snappedPos.x = round(snappedPos.x / gs) * gs
//        snappedPos.y = round(snappedPos.y / gs) * gs
//        level.moveSelectedVertices(pos: snappedPos, snappedVertex: clickedVertex)
//    }

    //
    // Actions
    //
    @IBAction func increaseGridDensity(_ sender: AnyObject?) {
        if gridSize > Const.gridMin {
            gridSize /= 2
            self.setNeedsDisplay(self.bounds)
        } else {
            NSBeep()
        }
    }

    @IBAction func decreaseGridDensity(_ sender: AnyObject?) {
        if gridSize < Const.gridMax {
            gridSize *= 2
            self.setNeedsDisplay(self.bounds)
        } else {
            NSBeep()
        }
    }

    fileprivate func pointerPosition() -> NSPoint {
        guard let windowPos = self.window?.mouseLocationOutsideOfEventStream else {
            return NSPoint(x: self.bounds.size.width / 2, y: self.bounds.size.height / 2)   // default to centre
        }
        return self.convert(windowPos, from: nil)
    }

    @IBAction func zoomIn(_ sender: AnyObject?) {
        if scale < Const.scaleMax {
            doMagnification(Const.zoomKeyAmount, cursorpos: self.pointerPosition())
            self.setNeedsDisplay(self.bounds)
        } else {
            NSBeep()
        }
    }

    @IBAction func zoomOut(_ sender: AnyObject?) {
        if scale > Const.scaleMin {
            doMagnification(-Const.zoomKeyAmount, cursorpos: self.pointerPosition())
            self.setNeedsDisplay(self.bounds)
        } else {
            NSBeep()
        }
    }

    override func selectAll(_ sender: Any?) {
        guard let level = self.level else {
            return
        }
        if level.selectAllVertices() {
            self.setNeedsDisplay(self.bounds)
        }
        
    }

    @IBAction func clearSelection(_ sender: Any?) {
        guard let level = self.level else {
            return
        }
        if level.clearSelection() {
            self.setNeedsDisplay(self.bounds)
        }
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(MapView.increaseGridDensity(_:)) {
            return self.gridSize > Const.gridMin
        }
        if menuItem.action == #selector(MapView.decreaseGridDensity(_:)) {
            return self.gridSize < Const.gridMax
        }
        if menuItem.action == #selector(MapView.zoomIn(_:)) {
            return self.scale < Const.scaleMax
        }
        if menuItem.action == #selector(MapView.zoomOut(_:)) {
            return self.scale > Const.scaleMin
        }
        if menuItem.action == #selector(MapView.selectAll(_:)) ||
            menuItem.action == #selector(MapView.clearSelection(_:))
        {
            return self.level != nil
        }
        return super.validateMenuItem(menuItem)
    }
}

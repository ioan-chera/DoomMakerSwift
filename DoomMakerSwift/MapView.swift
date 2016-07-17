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
    func mapViewPositionUpdated(position: NSPoint)
}

class MapView: NSView {
    weak var delegate: MapViewDelegate? {
        didSet {
            delegate?.mapViewGridSizeUpdated()
            delegate?.mapViewScaleUpdated()
            delegate?.mapViewPositionUpdated(NSPoint())
        }
    }

    private var translate = NSPoint()
    var scale = CGFloat(1) {
        didSet {
            delegate?.mapViewScaleUpdated()
        }
    }
    private var rotate = Float(0)
    private var rotatingGesture = false

    private var lastUpdate = NSTimeInterval()

    private var trackingArea: NSTrackingArea?

    var gridSize = Const.gridDefault {
        didSet {
            delegate?.mapViewGridSizeUpdated()
        }
    }

    struct Const {
        private static let gridWidth = CGFloat(1) / (NSScreen.mainScreen()?.backingScaleFactor ?? 1)
        private static let gridColor = NSColor(red: 0, green: CGFloat(0.5), blue: CGFloat(0.5), alpha: 1)
        private static let linedefWidth = CGFloat(1)
        private static let vertexRadius = CGFloat(1.5)
        private static let movePeriod = 1.0 / 30
        private static let gridMin = 2
        static let gridDefault = 8
        private static let gridMax = 1024
        private static let scaleMin = CGFloat(0.1)
        private static let scaleMax = CGFloat(10)
        private static let rotateSnapDegrees = Float(5)
        private static let zoomKeyAmount = CGFloat(0.25)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.blackColor().CGColor
        let area = NSTrackingArea(rect: self.bounds, options: [.ActiveInKeyWindow, .InVisibleRect, .MouseMoved], owner: self, userInfo: nil)
        trackingArea = area
        self.addTrackingArea(area)
    }

    override func updateTrackingAreas() {
        guard var area = trackingArea else {
            return super.updateTrackingAreas()
        }
        removeTrackingArea(area)
        area = NSTrackingArea(rect: self.bounds, options: [.ActiveInKeyWindow, .InVisibleRect, .MouseMoved], owner: self, userInfo: nil)
        trackingArea = area
        addTrackingArea(area)
    }

    weak var level: Level? {
        didSet {
            self.setNeedsDisplayInRect(self.bounds)
        }
    }

    private func drawGrid(dirtyRect: NSRect) {

        let gridf = CGFloat(gridSize) * scale   // for casting's sake
        if gridf <= 2 {
            Const.gridColor.setFill()
            NSRectFill(dirtyRect)
            return
        }
        let path = NSBezierPath()
        path.lineWidth = Const.gridWidth
        Const.gridColor.setStroke()

        let disp = translate - floor(translate / gridf) * gridf

        let minx = ceil(dirtyRect.origin.x / gridf) * gridf
        let maxx = floor(dirtyRect.origin.x + dirtyRect.size.width / gridf) * gridf + 2 * gridf
        let miny = ceil(dirtyRect.origin.y / gridf) * gridf
        let maxy = floor(dirtyRect.origin.y + dirtyRect.size.height / gridf) * gridf + 2 * gridf

        for x in minx.stride(through: maxx, by: gridf) {
            path.moveToPoint(NSPoint(x: x, y: miny - gridf) + disp)
            path.lineToPoint(NSPoint(x: x, y: maxy + gridf) + disp)
        }
        for y in miny.stride(through: maxy, by: gridf) {
            path.moveToPoint(NSPoint(x: minx - gridf, y: y) + disp)
            path.lineToPoint(NSPoint(x: maxx, y: y) + disp)
            
        }
        path.stroke()
    }



    private func drawLines(dirtyRect: NSRect) {
        func transformed(p: NSPoint) -> NSPoint {
            return p.rotated(rotate) * scale + translate
        }

        guard let level = self.level else {
            return
        }

        let solids = NSBezierPath()
        let passables = NSBezierPath()
        let vertices = NSBezierPath()
        solids.lineWidth = Const.linedefWidth
        passables.lineWidth = Const.linedefWidth
        vertices.lineWidth = Const.linedefWidth

        for line in level.linedefs {
            if line.v1 < 0 || line.v1 >= level.vertices.count || line.v2 < 0 || line.v2 >= level.vertices.count || line.v1 == line.v2 {
                continue
            }

            let v1 = level.vertices[line.v1]
            let v2 = level.vertices[line.v2]
            let p1 = transformed(NSPoint(x: v1.x, y: v1.y))
            let p2 = transformed(NSPoint(x: v2.x, y: v2.y))

            if !Geom.lineClipsRect(p1, p2, rect: dirtyRect) {
                continue
            }

            if (line.flags & 1) == 1 {
                solids.moveToPoint(p1)
                solids.lineToPoint(p2)
            } else {
                passables.moveToPoint(p1)
                passables.lineToPoint(p2)
            }
        }
        NSColor.whiteColor().setStroke()
        solids.stroke()
        NSColor.grayColor().setStroke()
        passables.stroke()

        for vertex in level.vertices {
            if vertex.degree == 0 {
                continue
            }
            let p = transformed(NSPoint(x: vertex.x, y: vertex.y))
            if !NSPointInRect(p, dirtyRect) {
                continue
            }
            vertices.appendBezierPathWithOvalInRect(NSRect(x: p.x - Const.vertexRadius, y: p.y - Const.vertexRadius, width: Const.vertexRadius * 2, height: Const.vertexRadius * 2))
        }

        NSColor.greenColor().setFill()
        vertices.fill()
    }

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        drawGrid(dirtyRect)
        drawLines(dirtyRect)
    }

    override var acceptsFirstResponder: Bool {
        get {
            return true
        }
    }

    private func gamePos(cursorPos: NSPoint) -> NSPoint {
        return ((cursorPos - self.translate) / self.scale).rotated(-self.rotate)
    }

    private func setRotation(value: Float, cursorpos: NSPoint) {
        let center = gamePos(cursorpos)
        self.rotate = value
        let center2 = gamePos(cursorpos)
        self.translate = self.translate + (center2 - center).rotated(self.rotate) * self.scale
        capTranslation()
    }

    private func snapRotation(updateDisplay: Bool, cursorpos: NSPoint) {
        if self.rotatingGesture {
            self.setRotation(round(self.rotate / Const.rotateSnapDegrees) * Const.rotateSnapDegrees, cursorpos: cursorpos)
            self.rotatingGesture = false
            if updateDisplay {
                self.setNeedsDisplayInRect(self.bounds)
            }
        }
    }

    //
    // Events
    //

    private func capTranslation() {
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

    override func scrollWheel(theEvent: NSEvent) {
        let pixelScale = NSScreen.mainScreen()?.backingScaleFactor ?? 1

        // TODO: add scaling and rotation with the mouse wheel

        if theEvent.modifierFlags.contains(.AlternateKeyMask) {
            // Negative means move map towards me
            let cursorpos = self.convertPoint(theEvent.locationInWindow, fromView: nil)
            self.doMagnification(theEvent.scrollingDeltaY / 40, cursorpos: cursorpos)
            return
        }

        // TODO: also add hotkeys

        translate.x += theEvent.scrollingDeltaX * pixelScale
        translate.y -= theEvent.scrollingDeltaY * pixelScale

        capTranslation()

        // Also update position for the map
        let position = gamePos(self.convertPoint(theEvent.locationInWindow, fromView: nil))
        delegate?.mapViewPositionUpdated(position)

        self.setNeedsDisplayInRect(self.bounds)
    }

    private func doMagnification(amount: CGFloat, cursorpos: NSPoint) {
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

        self.setNeedsDisplayInRect(self.bounds)
    }

    override func magnifyWithEvent(event: NSEvent) {
        let cursorpos = self.convertPoint(event.locationInWindow, fromView: nil)
        self.doMagnification(event.magnification, cursorpos: cursorpos)
    }

    override func mouseMoved(theEvent: NSEvent) {
        let position = gamePos(self.convertPoint(theEvent.locationInWindow, fromView: nil))
        delegate?.mapViewPositionUpdated(position)
    }

    //
    // Actions
    //
    @IBAction func increaseGridDensity(sender: AnyObject?) {
        if gridSize > Const.gridMin {
            gridSize /= 2
            self.setNeedsDisplayInRect(self.bounds)
        } else {
            NSBeep()
        }
    }

    @IBAction func decreaseGridDensity(sender: AnyObject?) {
        if gridSize < Const.gridMax {
            gridSize *= 2
            self.setNeedsDisplayInRect(self.bounds)
        } else {
            NSBeep()
        }
    }

    private func pointerPosition() -> NSPoint {
        guard let windowPos = self.window?.mouseLocationOutsideOfEventStream else {
            return NSPoint(x: self.bounds.size.width / 2, y: self.bounds.size.height / 2)   // default to centre
        }
        return self.convertPoint(windowPos, fromView: nil)
    }

    @IBAction func zoomIn(sender: AnyObject?) {
        if scale < Const.scaleMax {
            doMagnification(Const.zoomKeyAmount, cursorpos: self.pointerPosition())
            self.setNeedsDisplayInRect(self.bounds)
        } else {
            NSBeep()
        }
    }

    @IBAction func zoomOut(sender: AnyObject?) {
        if scale > Const.scaleMin {
            doMagnification(-Const.zoomKeyAmount, cursorpos: self.pointerPosition())
            self.setNeedsDisplayInRect(self.bounds)
        } else {
            NSBeep()
        }
    }

    override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
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
        return super.validateMenuItem(menuItem)
    }
}

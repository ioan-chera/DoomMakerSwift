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
}

class MapView: NSView {
    weak var delegate: MapViewDelegate? {
        didSet {
            delegate?.mapViewGridSizeUpdated()
            delegate?.mapViewScaleUpdated()
        }
    }

    private var translate = NSPoint()
    private(set) var scale = CGFloat(1) {
        didSet {
            delegate?.mapViewScaleUpdated()
        }
    }
    private var rotate = Float(0)
    private var rotatingGesture = false

    private var lastUpdate = NSTimeInterval()

    private(set) var gridSize = 8 {
        didSet {
            delegate?.mapViewGridSizeUpdated()
        }
    }

    private var sortedLines: [Level.Linedef] = Array()

    private struct Const {
        private static let gridWidth = CGFloat(1) / (NSScreen.mainScreen()?.backingScaleFactor ?? 1)
        private static let gridColor = NSColor(red: 0, green: CGFloat(0.5), blue: CGFloat(0.5), alpha: 1)
        private static let linedefWidth = CGFloat(1)
        private static let vertexRadius = CGFloat(1.5)
        private static let movePeriod = 1.0 / 30
        private static let gridMin = 2
        private static let gridMax = 1024
        private static let scaleMin = CGFloat(0.1)
        private static let scaleMax = CGFloat(10)
        private static let rotateSnapDegrees = Float(5)
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

        NSColor.blackColor().setFill()
        NSRectFill(dirtyRect)

        drawGrid(dirtyRect)
        drawLines(dirtyRect)
    }

    override var acceptsFirstResponder: Bool {
        get {
            return true
        }
    }

    private func setRotation(value: Float, event: NSEvent) {
        let cursorpos = self.convertPoint(event.locationInWindow, fromView: nil)
        let center = ((cursorpos - self.translate) / self.scale).rotated(-self.rotate)
        self.rotate = value
        let center2 = ((cursorpos - self.translate) / self.scale).rotated(-self.rotate)
        self.translate = self.translate + (center2 - center).rotated(self.rotate) * self.scale
    }

    private func snapRotation(updateDisplay: Bool, event: NSEvent) {
        if self.rotatingGesture {
            self.setRotation(round(self.rotate / Const.rotateSnapDegrees) * Const.rotateSnapDegrees, event: event)
            self.rotatingGesture = false
            if updateDisplay {
                self.setNeedsDisplayInRect(self.bounds)
            }
        }
    }

    //
    // Events
    //

    override func scrollWheel(theEvent: NSEvent) {
        let scale = NSScreen.mainScreen()?.backingScaleFactor ?? 1

        // TODO: add scaling and rotation with the mouse wheel
        // TODO: also add hotkeys

        translate.x += theEvent.scrollingDeltaX * scale
        translate.y -= theEvent.scrollingDeltaY * scale
        self.setNeedsDisplayInRect(self.bounds)
    }

    override func magnifyWithEvent(event: NSEvent) {

        if (event.magnification > 0 && self.scale >= Const.scaleMax) ||
           (event.magnification < 0 && self.scale <= Const.scaleMin)
        {
            return
        }

        self.snapRotation(false, event: event)

        let cursorpos = self.convertPoint(event.locationInWindow, fromView: nil)
        let center = (cursorpos - self.translate) / self.scale
        self.scale *= 1 + event.magnification
        if self.scale >= Const.scaleMax {
            self.scale = Const.scaleMax
        } else if self.scale <= Const.scaleMin {
            self.scale = Const.scaleMin
        }
        let center2 = (cursorpos - self.translate) / self.scale
        self.translate = self.translate + (center2 - center) * self.scale

        self.setNeedsDisplayInRect(self.bounds)
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
}

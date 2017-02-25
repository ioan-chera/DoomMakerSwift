//
//  Document.swift
//  DoomMakerSwift
//
//  Created by ioan on 24.01.2016.
//  Copyright © 2016 Ioan Chera. All rights reserved.
//

import Cocoa

class Document: NSDocument, NSWindowDelegate, MapViewDelegate
{
    fileprivate let wad = Wad()
    fileprivate let editor: LevelEditor

    @IBOutlet var docWindow: NSWindow!
    @IBOutlet var levelChooser: NSPopUpButton!
    @IBOutlet var mapView: MapView!
    @IBOutlet var gridLabel: NSTextField!
    @IBOutlet var zoomLabel: NSTextField!
    @IBOutlet var xyLabel: NSTextField!
    @IBOutlet var rotationLabel: NSTextField!

    fileprivate weak var currentLevel: Level? {
        didSet {
            self.levelUpdated()
        }
    }

    fileprivate func levelUpdated() {
        let haveLevel = self.currentLevel != nil
        self.mapView.isHidden = !haveLevel
        self.gridLabel.isHidden = !haveLevel
        self.zoomLabel.isHidden = !haveLevel
        self.xyLabel.isHidden = !haveLevel
        self.rotationLabel.isHidden = !haveLevel

        if haveLevel {
            let defaults = UserDefaults.standard
            self.mapView.gridSize = defaults.integer(forKey: Preferences.gridSize)
            if self.mapView.gridSize == 0 {
                self.mapView.gridSize = MapView.Const.gridDefault
            }
            self.mapView.scale = CGFloat(defaults.double(forKey: Preferences.zoom))
            if self.mapView.scale == 0 {
                self.mapView.scale = 1
            }
            self.mapView.rotate = defaults.float(forKey: Preferences.rotation)
        }

        self.mapView.level = self.currentLevel
        self.mapView.delegate = haveLevel ? self : nil
    }

    override init()
    {
        self.editor = LevelEditor(wad: self.wad)
        super.init()
        // Add your subclass-specific initialization here
    }

    override func windowControllerDidLoadNib(_ aController: NSWindowController)
    {
        super.windowControllerDidLoadNib(aController)

        self.levelUpdated()

        self.updateLevelChooser()
    }

    //
    // DELEGATE METHODS
    //
    func mapViewGridSizeUpdated() {
        self.gridLabel.setText("Grid Size: \(self.mapView.gridSize)")
        UserDefaults.standard.set(self.mapView.gridSize, forKey: Preferences.gridSize)
    }

    func mapViewScaleUpdated() {
        self.zoomLabel.setText("Zoom: \(Int(round(self.mapView.scale * 100)))%")
        UserDefaults.standard.set(Double(self.mapView.scale), forKey: Preferences.zoom)
    }

    func mapViewRotationUpdated() {
        self.rotationLabel.setText("Rotation: \(Int(round(self.mapView.rotate / MapView.Const.rotateSnapDegrees) * MapView.Const.rotateSnapDegrees))˚")
        UserDefaults.standard.set(self.mapView.rotate, forKey: Preferences.rotation)
    }

    func mapViewPositionUpdated(_ position: NSPoint) {
        self.xyLabel.setText("X: \(Int(round(position.x)))  Y: \(Int(round(position.y)))")
    }

//    override func makeWindowControllers()
//    {
//        let controller = NSWindowController(windowNibName: "Document")
//        addWindowController(controller)
//    }

    override class func autosavesInPlace() -> Bool
    {
        return true
    }

    override var windowNibName: String? {
        // Returns the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
        return "Document"
    }

    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
        return self.wad.serialized()
    }

    override func read(from data: Data, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
        do
        {
            try self.wad.read(data)
            self.editor.updateFromWad()
        }
        catch Wad.ReadError.info(let info)
        {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: [NSLocalizedDescriptionKey: info])
        }
    }

    fileprivate func updateLevelChooser() {
        self.levelChooser.removeAllItems()
        for i in 0 ..< self.editor.levelCount {
            self.levelChooser.addItem(withTitle: self.editor.levelName(i))
            let item = self.levelChooser.item(at: i)!
            item.action = #selector(Document.levelChooserClicked(_:))
            item.target = self
            item.tag = i
        }

        // Check now if a level was added
        if let selected = self.levelChooser?.selectedItem {
            self.levelChooserClicked(selected)
        }
    }

    func levelChooserClicked(_ sender: AnyObject?) {
        let index = (sender as! NSMenuItem).tag
        self.currentLevel = self.editor.levelAtIndex(index) ?? self.editor.loadLevelAtIndex(index)
    }
}


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

import Cocoa

/**
 The template-provided Document class. Holds reference to Wad and LevelEditor.
 */
class Document: NSDocument, NSWindowDelegate, MapViewDelegate
{
    /// The wad: always available for the Document
    private let wad = Wad()

    /// The level editor: manages the levels from the same wad.
    private let editor: LevelEditor

    /// UI stuff
    @IBOutlet var docWindow: NSWindow!
    @IBOutlet var levelChooser: NSPopUpButton!
    @IBOutlet var mapView: MapView!
    @IBOutlet var gridLabel: NSTextField!
    @IBOutlet var zoomLabel: NSTextField!
    @IBOutlet var xyLabel: NSTextField!
    @IBOutlet var rotationLabel: NSTextField!

    /// Holds a reference to the currently edited level
    private weak var currentLevel: Level? {
        didSet {
            self.levelUpdated()
        }
    }

    /// Updates the UI when a level is changed
    fileprivate func levelUpdated() {
        let haveLevel = self.currentLevel != nil
        self.currentLevel?.document = self
        self.mapView.isHidden = !haveLevel
        self.gridLabel.isHidden = !haveLevel
        self.zoomLabel.isHidden = !haveLevel
        self.xyLabel.isHidden = !haveLevel
        self.rotationLabel.isHidden = !haveLevel

        // Get settings from reference
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

    /// Initializer
    override init()
    {
        self.editor = LevelEditor(wad: self.wad)
        super.init()
        // Add your subclass-specific initialization here
    }

    /// When the NIB is loaded
    override func windowControllerDidLoadNib(_ aController: NSWindowController)
    {
        super.windowControllerDidLoadNib(aController)

        self.levelUpdated()

        self.updateLevelChooser()
    }

    //
    // DELEGATE METHODS
    //

    /// When the grid size is updated, change the UI
    func mapViewGridSizeUpdated() {
        self.gridLabel.setText("Grid Size: \(self.mapView.gridSize)")
        UserDefaults.standard.set(self.mapView.gridSize, forKey: Preferences.gridSize)
    }

    /// When the map is scaled, change the UI
    func mapViewScaleUpdated() {
        self.zoomLabel.setText("Zoom: \(Int(round(self.mapView.scale * 100)))%")
        UserDefaults.standard.set(Double(self.mapView.scale), forKey: Preferences.zoom)
    }

    /// When the map is rotated, change the UI
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

    /// It should autosave.
    override class func autosavesInPlace() -> Bool
    {
        return true
    }

    /// NIB name
    override var windowNibName: String? {
        // Returns the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
        return "Document"
    }

    /// When saving
    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
        editor.checkDirty()
        return self.wad.serialized()
    }

    /// When opening
    override func read(from data: Data, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
        do
        {
            try self.wad.read(data)
            self.editor.updateFromWad()
            self.updateLevelChooser()
        }
        catch Wad.ReadError.info(let info)
        {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: [NSLocalizedDescriptionKey: info])
        }
    }

    /// Update the level popup button
    private func updateLevelChooser() {
        if self.levelChooser == nil {
            return
        }
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

    /// When the level popup is clicked
    func levelChooserClicked(_ sender: AnyObject?) {
        let index = (sender as! NSMenuItem).tag
        self.currentLevel = self.editor.levelAtIndex(index) ?? self.editor.loadLevelAtIndex(index)
    }

    /// Notifies the map view to update
    func updateView() {
        self.mapView.setNeedsDisplay(self.mapView.bounds)
    }
}


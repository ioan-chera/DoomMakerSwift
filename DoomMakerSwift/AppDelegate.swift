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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var verticesModeItem: NSMenuItem!
    @IBOutlet var linedefsModeItem: NSMenuItem!
    @IBOutlet var sectorsModeItem: NSMenuItem!
    @IBOutlet var thingsModeItem: NSMenuItem!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Load resources
        let data = try! Data(contentsOf: Bundle.main.url(forResource: "doom2", withExtension: "json")!)
        let thingConfig = try! JSONSerialization.jsonObject(with: data) as! NSDictionary
        loadIdThingMap(jsonConfig: thingConfig)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func updateMode(_ mode: Level.Mode) {
        func check(_ val: Level.Mode) -> NSControl.StateValue {
            return mode == val ? NSControl.StateValue.on : NSControl.StateValue.off
        }
        verticesModeItem.state = check(Level.Mode.vertices)
        linedefsModeItem.state = check(Level.Mode.linedefs)
        sectorsModeItem.state = check(Level.Mode.sectors)
        thingsModeItem.state = check(Level.Mode.things)
    }

    func appSupportDir() -> URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)
        let url = urls[0]
        let subUrl = url.appendingPathComponent(Bundle.main.bundleIdentifier!)
        try! FileManager.default.createDirectory(at: subUrl, withIntermediateDirectories: true, attributes: nil)
        return subUrl
    }
}

func appDelegate() -> AppDelegate {
    return NSApp.delegate as! AppDelegate
}

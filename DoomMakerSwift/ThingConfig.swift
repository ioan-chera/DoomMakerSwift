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

import AppKit
import Foundation

//
// Thing definition for editor's view
//
struct ThingType {
    let category: String
    let name: String
    let id: Int
    let radius: Int
    let color: NSColor

    static let unknown = ThingType(category: "Unknown", name: "Unknown", id: 0, radius: 20, color: NSColor.gray)
}

// Maps doomednums to thing definitions
var idThingMap: [Int: ThingType] = [:]

//
// Loads the id-thing map from a JSON config
//
func loadIdThingMap(jsonConfig: NSDictionary) {
    idThingMap = [:]    // always clear it
    guard let categories = jsonConfig["thingCategories"] as? NSArray else {
        return
    }
    for categoryObject in categories {
        guard let category = categoryObject as? NSDictionary else {
            continue
        }
        guard let things = category["things"] as? NSArray else {
            continue
        }
        let categoryName = category["category"] as? String
        let radius = category["radius"] as? Int
        let colorString = category["color"] as? String
        for thingObject in things {
            guard let thing = thingObject as? NSDictionary else {
                continue
            }
            guard let id = thing["id"] as? Int else {
                continue
            }
            let thingRadius = thing["radius"] as? Int
            let name = thing["name"] as? String
            let thingColorString = thing["color"] as? String
            idThingMap[id] = ThingType(category: categoryName ?? "Others",
                                       name: name ?? "Unknown",
                                       id: id,
                                       radius: thingRadius ?? radius ?? 20,
                                       color: NSColor(hex: thingColorString ?? colorString ?? "#808080"))
        }
    }
}

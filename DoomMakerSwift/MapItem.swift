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

///
/// Item that has to be saved and loaded from map
///
protocol Serializable: class {
    init(data: [UInt8])
    var serialized: [UInt8] { get }
}

///
/// Individual map item. It mainly is storable in sets
///
class IndividualItem: Hashable {
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    static func == (lhs: IndividualItem, rhs: IndividualItem) -> Bool {
        return lhs === rhs
    }
}

///
/// This is a map editor item (thing, linedef, vertex, sector). Sidedefs are
/// excluded.
///
class InteractiveItem: IndividualItem {
    var draggables: Set<DraggedItem> {
        return Set()
    }
    var linedefs: Set<Linedef> {
        return Set()
    }
    var sectors: Set<Sector> {
        return Set()
    }
}

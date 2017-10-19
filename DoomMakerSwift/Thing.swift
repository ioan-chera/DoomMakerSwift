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

///
/// Map thing
///
final class Thing: DraggedItem, MapItem {
    var angle:Int16 = 0   // angle
    var type:Int16 = 0    // doomednum
    var flags:Int16 = 0   // spawn options

    var info: ThingType {
        get {
            return idThingMap[Int(type)] ?? ThingType.unknown
        }
    }

    init(data: [UInt8]) {
        super.init(x: 0, y: 0)
        DataReader(data).short(&x).short(&y).short(&angle).short(&type)
            .short(&flags)
    }

    func getData() -> [UInt8] {
        return DataWriter([]).short(x).short(y).short(angle).short(type)
            .short(flags).data
    }
}

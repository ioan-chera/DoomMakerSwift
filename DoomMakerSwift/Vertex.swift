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

final class Vertex: DraggedItem, Serializable, CustomStringConvertible {

    private var mLinedefs = Set<Linedef>()

    init(data: [UInt8]) {
        super.init(x: 0, y: 0)
        DataReader(data).short(&x).short(&y)
    }

    var serialized: [UInt8] {
        return DataWriter([]).short(x).short(y).data
    }

    func addLine(_ line: Linedef) {
        mLinedefs.insert(line)
    }

    func removeLine(_ line: Linedef) {
        mLinedefs.remove(line)
    }

    //
    // MARK: InteractiveItem
    //
    override var linedefs: Set<Linedef> {
        return mLinedefs
    }

    override var sectors: Set<Sector> {
        var result = Set<Sector>()
        for linedef in mLinedefs {
            result.formUnion(linedef.sectors)
        }
        return result
    }

    //
    // MARK: various map utilities
    //
    func connectingLine(with vertex: Vertex) -> Linedef? {
        return linedefs.intersection(vertex.linedefs).first
    }

    func samePosition(_ vertex: Vertex) -> Bool {
        return x == vertex.x && y == vertex.y
    }

    //
    // MARK: string representation
    //
    var description: String {
        return "(\(x), \(y))"
    }
}

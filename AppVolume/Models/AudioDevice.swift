import Foundation

struct AudioDevice: Identifiable, Equatable, Hashable {
    let objectID: UInt32
    let uid: String
    let name: String
    let isVirtual: Bool
    let isDefaultOutput: Bool

    var id: String { uid }
}

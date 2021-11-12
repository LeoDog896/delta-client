import Foundation

/// A component storing an entity's UUID. Not to be confused with ``EntityId``.
public struct EntityUUID {
  public var uuid: UUID
  
  public init(_ uuid: UUID) {
    self.uuid = uuid
  }
}

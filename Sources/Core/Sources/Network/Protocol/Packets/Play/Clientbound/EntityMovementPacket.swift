import Foundation

public struct EntityMovementPacket: ClientboundPacket {
  public static let id: Int = 0x2b
  
  public var entityId: Int
  
  public init(from packetReader: inout PacketReader) throws {
    entityId = packetReader.readVarInt()
  }
  
  public func handle(for client: Client) throws {
    if let velocity = client.game.component(entityId: entityId, EntityVelocity.self) {
      velocity.value = EntityVelocity(x: 0.0, y: 0.0, z: 0.0)
    }
  }
}

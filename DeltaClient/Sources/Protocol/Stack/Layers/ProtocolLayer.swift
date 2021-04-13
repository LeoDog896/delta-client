//
//  ProtocolLayer.swift
//  DeltaClient
//
//  Created by Rohan van Klinken on 31/3/21.
//

import Foundation
import os

class ProtocolLayer: InnermostNetworkLayer {
  typealias Packet = ServerboundPacket
  typealias Output = PacketReader
  
  var inboundSuccessor: InboundNetworkLayer? = nil
  var outboundSuccessor: OutboundNetworkLayer?
  
  var handler: ((PacketReader) -> Void)?
  var outboundThread: DispatchQueue
  
  init(outboundThread: DispatchQueue) {
    self.outboundThread = outboundThread
  }
  
  func handleInbound(_ buffer: Buffer) {
    let packetReader = PacketReader(buffer: buffer)
    if let callback = handler {
      callback(packetReader)
    }
  }
  
  func send(_ packet: ServerboundPacket) {
    outboundThread.sync {
      if let nextLayer = self.outboundSuccessor {
        let buffer = packet.toBuffer()
        nextLayer.handleOutbound(buffer)
      }
    }
  }
}
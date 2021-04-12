// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: CacheBlockModelPalette.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

//
//  CacheBlockModelPalette.proto
//  DeltaClient
//
//  Created by Rohan van Klinken on 31/3/21.

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

struct CacheBlockModelPalette {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var blockModelPalette: Dictionary<UInt32,CacheBlockModelContainer> = [:]

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

extension CacheBlockModelPalette: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "CacheBlockModelPalette"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "blockModelPalette"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeMapField(fieldType: SwiftProtobuf._ProtobufMessageMap<SwiftProtobuf.ProtobufUInt32,CacheBlockModelContainer>.self, value: &self.blockModelPalette) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.blockModelPalette.isEmpty {
      try visitor.visitMapField(fieldType: SwiftProtobuf._ProtobufMessageMap<SwiftProtobuf.ProtobufUInt32,CacheBlockModelContainer>.self, value: self.blockModelPalette, fieldNumber: 1)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: CacheBlockModelPalette, rhs: CacheBlockModelPalette) -> Bool {
    if lhs.blockModelPalette != rhs.blockModelPalette {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

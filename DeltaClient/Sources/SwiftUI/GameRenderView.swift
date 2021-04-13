//
//  GameRenderView.swift
//  DeltaClient
//
//  Created by Rohan van Klinken on 6/3/21.
//

import SwiftUI
import os

enum GameViewStateEnum {
  case downloadingTerrain
  case playing
}

struct GameRenderView: View {
  @ObservedObject var state = ViewState<GameViewStateEnum>(initialState: .downloadingTerrain)
  
  let client: Client
  let eventManager: EventManager
  
  init(serverDescriptor: ServerDescriptor, managers: Managers) {
    self.client = Client(managers: managers, serverDescriptor: serverDescriptor)
    self.eventManager = managers.eventManager
    
    managers.eventManager.registerEventHandler(handleEvent, eventName: "downloadedTerrain")
    self.client.play()
  }
  
  func handleEvent(_ event: EventManager.Event) {
    switch event {
      case .downloadedTerrain:
        Logger.log("finished downloading terrain")
        state.update(to: .playing)
      default:
        break
    }
  }
  
  var body: some View {
    Group {
      switch state.value {
        case .downloadingTerrain:
          Text("downloading terrain")
        case .playing:
          MetalView(client: client)
      }
    }
    .navigationTitle("Delta Client")
    .toolbar(content: {
      Button("leave") {
        client.quit()
        eventManager.triggerEvent(.leaveServer)
      }
    })
  }
}
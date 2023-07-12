//
//  ContentView.swift
//  ojhRPOaj
//
//  Created by Nathan on 7/10/23.
//

import SwiftUI

struct ContentView: View {
	@EnvironmentObject var mpcManager: MPCManager
	
	@State private var showJoin = false
	
    var body: some View {
		VStack {
			Button("Host") {
				mpcManager.advertise()
			}
			
			Button("Join") {
				mpcManager.browse()
				showJoin = true
			}
			
			Text("Lobby Member Count: \(mpcManager.lobbyPeers.count)")
			Text("Peer ID: \(mpcManager.localPeer.displayName)")
		}
		.sheet(isPresented: $showJoin, content: JoinView.init)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
			.environmentObject(MPCManager())
    }
}

struct JoinView: View {
	@EnvironmentObject var mpcManager: MPCManager
	
	var body: some View {
		VStack {
			ForEach(mpcManager.discoveredPeers) { peer in
				Button("\(peer.displayName)") {
					mpcManager.join(peer: peer)
				}
			}
		}
		.padding()
	}
}

//
//  ojhRPOajApp.swift
//  ojhRPOaj
//
//  Created by Nathan on 7/10/23.
//

import SwiftUI

@main
struct ojhRPOajApp: App {
	@ObservedObject var mpcManager = MPCManager()
	
    var body: some Scene {
        WindowGroup {
            ContentView()
				.environmentObject(mpcManager)
        }
    }
}

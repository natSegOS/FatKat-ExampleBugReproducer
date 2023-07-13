//
//  MPCManager.swift
//  ojhRPOaj
//
//  Created by Nathan on 7/10/23.
//

import MultipeerConnectivity

class MPCManager: NSObject, ObservableObject {
	var session: MCSession?
	var advertiser: MCNearbyServiceAdvertiser?
	var browser: MCNearbyServiceBrowser?
	
	@Published var localPeer: MCPeerID
	
	var iteration = 1
	
	var discoveryInfo: [String: String] {
		["test": String(iteration)]
	}
	
	@Published var discoveredPeers = [MCPeerID: [String: String]]()
	@Published var lobbyPeers = [MCPeerID]()
	
	private var connectionClosures = [MCPeerID: () -> Void]()
	private var isJoining = false
	
	override init() {
		localPeer = MCPeerID(displayName: UUID().uuidString)
		super.init()
		
		createSession()
	}
	
	func createSession() {
		session = MCSession(peer: localPeer, securityIdentity: nil, encryptionPreference: .required)
		session?.delegate = self
		print("Created session")
	}
	
	func destroySession() {
		session?.disconnect()
		session?.delegate = nil
		session = nil
		print("Destroyed session")
	}
	
	func host() {
		advertise()
		browse()
		print("Hosted lobby")
	}
	
	func advertise(withDiscoveryInfo info: [String: String]? = nil) {
		guard advertiser == nil else { return }
		
		advertiser = MCNearbyServiceAdvertiser(peer: localPeer, discoveryInfo: info ?? discoveryInfo, serviceType: "test-lol")
		advertiser?.delegate = self
		advertiser?.startAdvertisingPeer()
		print("Advertised")
	}
	
	func stopAdvertising() {
		advertiser?.stopAdvertisingPeer()
		advertiser?.delegate = nil
		advertiser = nil
		print("Stopped advertising")
	}
	
	func browse() {
		guard browser == nil else { return }
		
		browser = MCNearbyServiceBrowser(peer: localPeer, serviceType: "test-lol")
		browser?.delegate = self
		browser?.startBrowsingForPeers()
		print("Browsed")
	}
	
	func stopBrowsing() {
		browser?.stopBrowsingForPeers()
		browser?.delegate = nil
		browser = nil
		print("Stopped browsing")
	}
	
	func reset() {
		destroySession()
		stopAdvertising()
		stopBrowsing()
		
		DispatchQueue.main.async { [weak self] in
			self!.localPeer = MCPeerID(displayName: UUID().uuidString)
			self!.discoveredPeers.removeAll(keepingCapacity: true)
			self!.lobbyPeers.removeAll(keepingCapacity: true)
			
			self!.createSession()
			print("Reset")
		}
	}
	
	func join(peer: MCPeerID, recurse: Bool = true) {
		guard let info = discoveredPeers[peer] else { return }
		
		advertise(withDiscoveryInfo: info)
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
			self?.sendInvitationRequest(to: peer, onConnection: {
				self?.sendLobbyJoinRequest(to: peer)
			})
		}
	}
	
	func sendInvitationRequest(to peer: MCPeerID, onConnection:  @escaping () -> Void) {
		isJoining = true
		let invitationRequest = try! JSONEncoder().encode(InvitationContext.invitationRequest)
		
		connectionClosures[peer] = { [weak self] in
			onConnection()
			self!.connectionClosures.removeValue(forKey: peer)
		}
		
		browser!.invitePeer(peer, to: session!, withContext: invitationRequest, timeout: 30)
		print("Sent invitation request")
	}
	
	func sendInvite(to peer: MCPeerID) {
		let invite = try! JSONEncoder().encode(InvitationContext.invite)
		browser!.invitePeer(peer, to: session!, withContext: invite, timeout: 30)
		print("Sent invite")
	}
	
	func sendLobbyJoinRequest(to peer: MCPeerID) {
		let joinRequest = try! JSONEncoder().encode(DataSend.joinRequest)
		try! session!.send(joinRequest, toPeers: [peer], with: .reliable)
		print("Sent join request")
	}
	
	func acceptLobbyJoinRequest(from peer: MCPeerID) {
		DispatchQueue.main.async { [weak self] in
			self!.lobbyPeers.append(peer)
		}
		
		let acceptance = try! JSONEncoder().encode(DataSend.acceptJoinRequest)
		try! session!.send(acceptance, toPeers: [peer], with: .reliable)
		print("Accepted join request")
	}
	
	func leaveLobby() {
		reset()
		print("Left lobby")
	}
	
	deinit {
		stopAdvertising()
		stopBrowsing()
		destroySession()
		discoveredPeers.removeAll()
		lobbyPeers.removeAll()
		connectionClosures.removeAll()
		isJoining = false
		print("Deinitialized MPCManager")
	}
}

enum DataSend: Codable {
	case joinRequest
	case acceptJoinRequest
}

extension MPCManager: MCSessionDelegate {
	func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
		print("Changed state to: \(state)")
		
		if state == .connected && isJoining {
			isJoining = false
			connectionClosures[peerID]?()
			print("State changed to connected so called connection closure")
		}
	}
	
	func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
		print("Received data")
		
		let dataSend = try! JSONDecoder().decode(DataSend.self, from: data)
		
		switch dataSend {
		case .joinRequest:
			acceptLobbyJoinRequest(from: peerID)
			
		case .acceptJoinRequest:
			DispatchQueue.main.async { [weak self] in
				self!.lobbyPeers.append(peerID)
				print("Appended to lobbyPeers array")
			}
		}
	}
	
	func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
		fatalError("Streams not supported")
	}
	
	func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
		certificateHandler(true)
		print("Accepted certificate")
	}
	
	func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
		fatalError("Resources not supported")
	}
	
	func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
		fatalError("Resources not supported")
	}
}

enum InvitationContext: Codable {
	case invite
	case invitationRequest
}

extension MPCManager: MCNearbyServiceAdvertiserDelegate {
	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
		print("Failed to advertise:\n\(error)")
	}
	
	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
		let invitationContext = try! JSONDecoder().decode(InvitationContext.self, from: context!)
		
		switch invitationContext {
		case .invite:
			invitationHandler(true, session)
			print("Accepted invitation handler")
			
		case .invitationRequest:
			invitationHandler(false, nil)
			print("Denied invitation handler")
			sendInvite(to: peerID)
		}
	}
}

extension MPCManager: MCNearbyServiceBrowserDelegate {
	func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
		print("Failed to browse:\n\(error)")
	}
	
	func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
		guard peerID.displayName != localPeer.displayName else { return }
		guard !discoveredPeers.contains(where: { $0.key.displayName == peerID.displayName } ) else { return }
		
		print("Found peer")
		discoveredPeers[peerID] = info ?? [:]
	}
	
	func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
		print("Lost peer")
		discoveredPeers.removeValue(forKey: peerID)
	}
}

extension MCPeerID: Identifiable {
	public var id: String { displayName }
}

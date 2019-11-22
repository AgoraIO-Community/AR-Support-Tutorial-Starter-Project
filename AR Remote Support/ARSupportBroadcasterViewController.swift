//
//  AgoraSupportBroadcasterViewController.swift
//  AR Remote Support
//
//  Created by digitallysavvy on 10/30/19.
//  Copyright © 2019 Agora.io. All rights reserved.
//

import UIKit
import ARKit
import ARVideoKit
import AgoraRtcEngineKit

class ARSupportBroadcasterViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, RenderARDelegate, AgoraRtcEngineDelegate {
    
    var sceneView : ARSCNView!                          // AR SceneView
    
    var micBtn: UIButton!                               // button to mute/un-mute the microphone
    var remoteVideoView: UIView!                        // video stream from remote user
    var lineColor: UIColor = UIColor.systemBlue         // color to use when drawing
    
    // Agora
    var agoraKit: AgoraRtcEngineKit!                    // Agora.io Video Engine reference
    var channelName: String!                            // name of the channel to join
    let arVideoSource: ARVideoSource = ARVideoSource()  // for passing the AR camera as the stream
    
    var sessionIsActive = false                         // keep track if the video session is active or not
    var remoteUser: UInt?                               // remote user id
    var dataStreamId: Int! = 27                         // id for data stream
    var streamIsEnabled: Int32 = -1                     // acts as a flag to keep track if the data stream is enabled
    
    var remotePoints: [CGPoint] = []                    // list of touches received from the remote user
    var touchRoots: [SCNNode] = []                      // list of root nodes for each set of touches drawn - for undo purposes
    
    var arvkRenderer: RecordAR!                         // ARVideoKit Renderer - used as an off-screen renderer
    
    let debug : Bool = true                             // toggle the debug logs
    
    // MARK: VC Events
    override func loadView() {
        super.loadView()
        createUI()                                      // init and add the UI elements to the view
        self.view.backgroundColor = UIColor.black       // set the background color 
        
        // TODO: Agora setup
        // - init engine
        // - set channel profile
        // - set video encoding configuration (dimensions, frame-rate, bitrate, orientation
        // - enable video
        // - set the video source to the custom AR source
        // - enable external audio souce (since video and audio are coming from seperate sources)
    }

    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        // Configure ARKit Session
        let configuration = ARWorldTrackingConfiguration()  // ARKit trackign configuration
        configuration.providesAudioData = true              // enable audio data
        configuration.isLightEstimationEnabled = false      // diable light estimation (save on processing)

        self.sceneView.session.run(configuration)           // set cunfiguration for ARKit session
        self.arvkRenderer?.prepare(configuration)           // set configuration for off-screen render
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // stop the ARVideoKit renderer
        arvkRenderer.rest()
        // Pause the view's session
        self.sceneView.session.pause()
        self.sceneView.removeFromSuperview()
        self.sceneView = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set ARKit render and session delegates
        self.sceneView.delegate = self
        self.sceneView.session.delegate = self
        
        // set up off screen renderer (ARVideoKit)
        self.arvkRenderer = RecordAR(ARSceneKit: self.sceneView)
        self.arvkRenderer?.renderAR = self // Set the renderer's delegate
        // Configure the renderer to always render the scene
        self.arvkRenderer?.onlyRenderWhileRecording = false
        // Configure ARKit content mode. Default is .auto
        self.arvkRenderer?.contentMode = .aspectFit
        // add environment light during rendering
        self.arvkRenderer?.enableAdjustEnvironmentLighting = true
        // Set the UIViewController orientations
        self.arvkRenderer?.inputViewOrientations = [.portrait]

        if debug {
            self.sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
            self.sceneView.showsStatistics = true
        }
        
        // TODO: Add Agora - join the channel
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let light = self.createLight(withPosition: SCNVector3(x: 0,y: 5,z: 0), andEulerRotation: SCNVector3(-Float.pi / 2, 0, 0))
        self.sceneView.scene.rootNode.addChildNode(light)
    }
    
    // MARK: Hide status bar
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: UI
    func createUI() {
        // Setup sceneview
        let sceneView = ARSCNView() //instantiate scene view
        self.view.insertSubview(sceneView, at: 0)
        
        //add sceneView layout contstraints
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        sceneView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        sceneView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        sceneView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        // set reference to sceneView
        self.sceneView = sceneView
        
        // add remote video view
        let remoteViewScale = self.view.frame.width * 0.33
        let remoteView = UIView()
        remoteView.frame = CGRect(x: self.view.frame.maxX - (remoteViewScale+15), y: self.view.frame.maxY - (remoteViewScale+25), width: remoteViewScale, height: remoteViewScale)
        remoteView.backgroundColor = UIColor.lightGray
        remoteView.layer.cornerRadius = 25
        remoteView.layer.masksToBounds = true
        self.view.insertSubview(remoteView, at: 1)
        self.remoteVideoView = remoteView
        
        // add branded logo to remote view
        guard let agoraLogo = UIImage(named: "agora-logo") else { return }
        let remoteViewBagroundImage = UIImageView(image: agoraLogo)
        remoteViewBagroundImage.frame = CGRect(x: (remoteViewScale/2)-37, y: (remoteViewScale/2)-45, width: 78, height: 84)
        remoteViewBagroundImage.alpha = 0.25
        remoteView.insertSubview(remoteViewBagroundImage, at: 1)
        
        // mic button
        let micBtn = UIButton()
        micBtn.frame = CGRect(x: self.view.frame.midX-37.5, y: self.view.frame.maxY-100, width: 75, height: 75)
        if let imageMicBtn = UIImage(named: "mic") {
            micBtn.setImage(imageMicBtn, for: .normal)
        } else {
            micBtn.setTitle("mute", for: .normal)
        }
        micBtn.addTarget(self, action: #selector(toggleMic), for: .touchDown)
        self.view.insertSubview(micBtn, at: 2)
        self.micBtn = micBtn
        
        //  back button
        let backBtn = UIButton()
        backBtn.frame = CGRect(x: self.view.frame.maxX-55, y: self.view.frame.minY + 20, width: 30, height: 30)
        backBtn.layer.cornerRadius = 10
        if let imageExitBtn = UIImage(named: "exit") {
            backBtn.setImage(imageExitBtn, for: .normal)
        } else {
            backBtn.setTitle("x", for: .normal)
        }
        backBtn.addTarget(self, action: #selector(popView), for: .touchUpInside)
        self.view.insertSubview(backBtn, at: 2)
    }
    
    // MARK: Button Events
    @IBAction func popView() {
        leaveChannel()                                  // leave the channel
        self.sessionIsActive = false                    // session is no longer active
        self.dismiss(animated: true, completion: nil)   // dismiss the view
    }
    
    @IBAction func toggleMic() {
        guard let activeMicImg = UIImage(named: "mic") else { return }
        guard let disabledMicImg = UIImage(named: "mute") else { return }
        if self.micBtn.imageView?.image == activeMicImg {
            // TODO: Disable Mic using Agora Engine
            self.micBtn.setImage(disabledMicImg, for: .normal)
            if debug {
                print("disable active mic")
            }
        } else {
            // TODO: Enable Mic using Agora Engine
            self.micBtn.setImage(activeMicImg, for: .normal)
            if debug {
                print("enable mic")
            }
        }
    }
    
    // MARK: Agora Interface
    func joinChannel() {
        // TODO: Set audio route to speaker
        // TODO: Join the channel
        UIApplication.shared.isIdleTimerDisabled = true     // Disable idle timmer
    }
    
    func leaveChannel() {
        // TODO: leave channel and end chat
        UIApplication.shared.isIdleTimerDisabled = false    // Enable idle timer
    }
    
    // MARK: ARVidoeKit Renderer
    func frame(didRender buffer: CVPixelBuffer, with time: CMTime, using rawBuffer: CVPixelBuffer) {
        // TODO: Pass rendered frame to Agora Engine
    }
    
    // MARK: Render delegate
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        // do something when scene will render
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // do something on render update
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        
    }
    
    // plane detection
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // anchor plane detection
    }
    
    // plane updating
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // anchor plane is updated
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        // anchor plane is removed
    }
    
     // MARK: Session delegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // TODO: check if we have points - draw one point per frame
    }
    
    func session(_ session: ARSession, didOutputAudioSampleBuffer audioSampleBuffer: CMSampleBuffer) {
        // TODO: Push audio data to Agora Engine
    }
    
    // MARK: AGORA DELEGATE
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid:UInt, size:CGSize, elapsed:Int) {
        // TODO: Set up remote view
        // TODO: Set session as active
        // TODO: create the data stream

    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        if debug {
            print("error: \(errorCode.rawValue)")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        if debug {
            print("warning: \(warningCode.rawValue)")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        if debug {
            print("local user did join channel with uid:\(uid)")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        if debug {
            print("remote user did joined of uid: \(uid)")
        }
        // TODO: keep track of the remote user -- limit to a single user
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        if debug {
            print("remote user did offline of uid: \(uid)")
        }
        // TODO: Nullify remote user reference
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didAudioMuted muted: Bool, byUid uid: UInt) {
        // add logic to show icon that remote stream is muted
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, receiveStreamMessageFromUid uid: UInt, streamId: Int, data: Data) {
        // successfully received message from user
        // decode the msg from data to string
        guard let dataAsString = String(bytes: data, encoding: String.Encoding.ascii) else { return }
        
        if debug {
            print("STREAMID: \(streamId)\n - DATA: \(data)\n - STRING: \(dataAsString)\n")
        }
        
        // TODO: Handle data message
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurStreamMessageErrorFromUid uid: UInt, streamId: Int, error: Int, missed: Int, cached: Int) {
        // message failed to send(
        if debug {
            print("STREAMID: \(streamId)\n - ERROR: \(error)")
        }
    }
    
    // MARK: Lights
    func createLight(withPosition position: SCNVector3, andEulerRotation rotation: SCNVector3) -> SCNNode {
        // Create a directional light node with shadow
        let directionalNode : SCNNode = SCNNode()
        directionalNode.light = SCNLight()
        directionalNode.light?.type = SCNLight.LightType.directional
        directionalNode.light?.color = UIColor.white
        directionalNode.light?.castsShadow = true
        directionalNode.light?.automaticallyAdjustsShadowProjection = true
        directionalNode.light?.shadowSampleCount = 64
        directionalNode.light?.shadowRadius = 16
        directionalNode.light?.shadowMode = .deferred
        directionalNode.light?.shadowMapSize = CGSize(width: 1024, height: 1024)
        directionalNode.light?.shadowColor = UIColor.black.withAlphaComponent(0.5)
        directionalNode.position = position
        directionalNode.eulerAngles = rotation
        
        return directionalNode
    }

}


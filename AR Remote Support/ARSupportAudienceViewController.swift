//
//  AgoraSupportAudienceViewController.swift
//  AR Remote Support
//
//  Created by digitallysavvy on 10/30/19.
//  Copyright © 2019 Agora.io. All rights reserved.
//

import UIKit
import AgoraRtcEngineKit

class ARSupportAudienceViewController: UIViewController, UIGestureRecognizerDelegate, AgoraRtcEngineDelegate {

    var touchStart: CGPoint!                // keep track of the initial touch point of each gesture
    var touchPoints: [CGPoint]!             // for drawing touches to the screen
    
    //  list of colors that user can choose from
    let uiColors: [UIColor] = [UIColor.systemBlue, UIColor.systemGray, UIColor.systemGreen, UIColor.systemYellow, UIColor.systemRed]
    
    var lineColor: UIColor!                 // active color to use when drawing
    let bgColor: UIColor = .white           // set the view bg color
    
    var drawingView: UIView!                // view to draw all the local touches
    var localVideoView: UIView!             // video stream of local camera
    var remoteVideoView: UIView!            // video stream from remote user
    var micBtn: UIButton!                   // button to mute/un-mute the microphone
    var colorSelectionBtn: UIButton!        // button to handle display or hiding the colors avialble to the user
    var colorButtons: [UIButton] = []       // keep track of the buttons for each color
    
    // Agora
    var agoraKit: AgoraRtcEngineKit!        // Agora.io Video Engine reference
    var channelName: String!                // name of the channel to join
     
    var sessionIsActive = false             // keep track if the video session is active or not
    var remoteUser: UInt?                   // remote user id
    var dataStreamId: Int! = 27             // id for data stream
    var streamIsEnabled: Int32 = -1         // acts as a flag to keep track if the data stream is enabled
    
    var dataPointsArray: [CGPoint] = []     // batch list of touches to be sent to remote user
    
    let debug: Bool = false                 // toggle the debug logs
    
    // MARK: VC Events
    override func loadView() {
        super.loadView()
        createUI() // init and add the UI elements to the view
        //  TODO: setup touch gestures
        
        // TODO: Add Agora setup
        // - init engine
        // - set channel profile
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.lineColor = self.uiColors.first        // set the active color to the first in the list
        self.view.backgroundColor = self.bgColor    // set the background color
        self.view.isUserInteractionEnabled = true   // enable user touch events
        
        //  TODO: Add Agora implementation
        //  - set video configuration
        //  - join the channel
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // do something when the view has appeared
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.sessionIsActive {
            leaveChannel();
        }
    }
    
    // MARK: Hide status bar
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: Gestures
    func setupGestures() {
        // TODO: Add pan gesture
    }
    
    // MARK: Touch Capture
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
       // TODO: Get the initial touch event
    }
    
    @IBAction func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
            // TODO: keep track of touches during pan guesture
        } else if gestureRecognizer.state == .ended {
            // TODO: Tidy up after the gesture ends
        }
    }
    
    func sendTouchPoints() {
        // TODO: Transmit touch data
    }
    
    func clearSubLayers() {
        // TODO: Remove touches drawn to the screen
    }
    
    // MARK: UI
    func createUI() {
        
        // add remote video view
        let remoteView = UIView()
        remoteView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
        remoteView.backgroundColor = UIColor.lightGray
        self.view.insertSubview(remoteView, at: 0)
        self.remoteVideoView = remoteView
        
        // add branded logo to remote view
        guard let agoraLogo = UIImage(named: "agora-logo") else { return }
        let remoteViewBagroundImage = UIImageView(image: agoraLogo)
        remoteViewBagroundImage.frame = CGRect(x: remoteView.frame.midX-56.5, y: remoteView.frame.midY-100, width: 117, height: 126)
        remoteViewBagroundImage.alpha = 0.25
        remoteView.insertSubview(remoteViewBagroundImage, at: 1)
        
        // ui view that the finger drawings will appear on
        let drawingView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height))
        self.view.insertSubview(drawingView, at: 1)
        self.drawingView = drawingView
        
        // add local video view
        let localViewScale = self.view.frame.width * 0.33
        let localView = UIView()
        localView.frame = CGRect(x: self.view.frame.maxX - (localViewScale+17.5), y: self.view.frame.maxY - (localViewScale+25), width: localViewScale, height: localViewScale)
        localView.layer.cornerRadius = 25
        localView.layer.masksToBounds = true
        localView.backgroundColor = UIColor.darkGray
        self.view.insertSubview(localView, at: 2)
        self.localVideoView = localView
        
        // mute button
        let micBtn = UIButton()
        micBtn.frame = CGRect(x: self.view.frame.midX-37.5, y: self.view.frame.maxY-100, width: 75, height: 75)
        if let imageMicBtn = UIImage(named: "mic") {
            micBtn.setImage(imageMicBtn, for: .normal)
        } else {
            micBtn.setTitle("mute", for: .normal)
        }
        micBtn.addTarget(self, action: #selector(toggleMic), for: .touchDown)
        self.view.insertSubview(micBtn, at: 3)
        self.micBtn = micBtn
        
        //  back button
        let backBtn = UIButton()
        backBtn.frame = CGRect(x: self.view.frame.maxX-55, y: self.view.frame.minY+20, width: 30, height: 30)
//        backBtn.layer.cornerRadius = 10
        if let imageExitBtn = UIImage(named: "exit") {
            backBtn.setImage(imageExitBtn, for: .normal)
        } else {
            backBtn.setTitle("x", for: .normal)
        }
        backBtn.addTarget(self, action: #selector(popView), for: .touchUpInside)
        self.view.insertSubview(backBtn, at: 3)
        
        // color palette button
        let colorSelectionBtn = UIButton(type: .custom)
        colorSelectionBtn.frame = CGRect(x: self.view.frame.minX+20, y: self.view.frame.maxY-60, width: 40, height: 40)
        if let colorSelectionBtnImage = UIImage(named: "color") {
            let tinableImage = colorSelectionBtnImage.withRenderingMode(.alwaysTemplate)
            colorSelectionBtn.setImage(tinableImage, for: .normal)
            colorSelectionBtn.tintColor = self.uiColors.first
        } else {
           colorSelectionBtn.setTitle("color", for: .normal)
        }
        colorSelectionBtn.addTarget(self, action: #selector(toggleColorSelection), for: .touchUpInside)
        self.view.insertSubview(colorSelectionBtn, at: 4)
        self.colorSelectionBtn = colorSelectionBtn
        
        // set up color buttons
        for (index, color) in uiColors.enumerated() {
            let colorBtn = UIButton(type: .custom)
            colorBtn.frame = CGRect(x: colorSelectionBtn.frame.midX-13.25, y: colorSelectionBtn.frame.minY-CGFloat(35+(index*35)), width: 27.5, height: 27.5)
            colorBtn.layer.cornerRadius = 0.5 * colorBtn.bounds.size.width
            colorBtn.clipsToBounds = true
            colorBtn.backgroundColor = color
            colorBtn.addTarget(self, action: #selector(setColor), for: .touchDown)
            colorBtn.alpha = 0
            colorBtn.isHidden = true
            colorBtn.isUserInteractionEnabled = false
            self.view.insertSubview(colorBtn, at: 3)
            self.colorButtons.append(colorBtn)
        }
        
        // add undo button
        let undoBtn = UIButton()
        undoBtn.frame = CGRect(x: colorSelectionBtn.frame.maxX+25, y: colorSelectionBtn.frame.minY+5, width: 30, height: 30)
        if let imageUndoBtn = UIImage(named: "undo") {
            undoBtn.setImage(imageUndoBtn, for: .normal)
        } else {
            undoBtn.setTitle("undo", for: .normal)
        }
        undoBtn.addTarget(self, action: #selector(sendUndoMsg), for: .touchUpInside)
        self.view.insertSubview(undoBtn, at: 3)
        
    }
    
    // MARK: Button Events
    @IBAction func popView() {
        leaveChannel()                                  // leave the channel
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
    
    @IBAction func toggleColorSelection() {
        guard let colorSelectionBtn = self.colorSelectionBtn else { return }
        var isHidden = false
        var alpha: CGFloat = 1
        
        if colorSelectionBtn.alpha == 1 {
            colorSelectionBtn.alpha = 0.65
        } else {
            colorSelectionBtn.alpha = 1
            alpha = 0
            isHidden = true
        }
        
        for button in self.colorButtons {
            // highlihgt the selected color
            button.alpha = alpha
            button.isHidden = isHidden
            button.isUserInteractionEnabled = !isHidden
            // use CGColor in comparison: BackgroundColor and TintColor do not init the same for the same UIColor.
            if button.backgroundColor?.cgColor == colorSelectionBtn.tintColor.cgColor {
                button.layer.borderColor = UIColor.white.cgColor
                button.layer.borderWidth = 2
            } else {
                button.layer.borderWidth = 0
            }
        }

    }
    
    @IBAction func setColor(_ sender: UIButton) {
        guard let colorSelectionBtn = self.colorSelectionBtn else { return }
        colorSelectionBtn.tintColor = sender.backgroundColor
        self.lineColor = colorSelectionBtn.tintColor
        toggleColorSelection()
        // TODO: Send data message with updated color
    }
    
    @IBAction func sendUndoMsg() {
        // TODO: Send undo msg
    }
    
    // MARK: Agora Implementation
    func setupLocalVideo() {
        // TODO: enable the local video stream
        
        // TODO: Set video encoding configuration (dimensions, frame-rate, bitrate, orientation)
        
        // TODO: Set up local video view
    }
    
    func joinChannel() {
        // TODO: Set audio route to speaker
        // TODO: Join channel
        UIApplication.shared.isIdleTimerDisabled = true     // Disable idle timer
    }
    
    func leaveChannel() {
        // TODO: leave channel - end chat session
        self.sessionIsActive = false                        // session is no longer active
        UIApplication.shared.isIdleTimerDisabled = false    // Enable idle timer
    }
    
    // MARK: Agora Delegate
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid:UInt, size:CGSize, elapsed:Int) {
         // first remote video frame
        if self.debug {
            print("firstRemoteVideoDecoded for Uid: \(uid)")
        }
        // TODO: Setup remote video view
        // TODO: Set session as active
        // TODO: create the data stream

    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        if self.debug {
            print("error: \(errorCode.rawValue)")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        if self.debug {
            print("warning: \(warningCode.rawValue)")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        if self.debug {
            print("local user did join channel with uid:\(uid)")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        if self.debug {
            print("remote user did joined of uid: \(uid)")
        }
        // TODO: keep track of the remote user -- limit to a single user
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        if self.debug {
            print("remote user did offline of uid: \(uid)")
        }
        // TODO: Nullify remote user reference
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didAudioMuted muted: Bool, byUid uid: UInt) {
        // add logic to show icon that remote stream is muted
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, receiveStreamMessageFromUid uid: UInt, streamId: Int, data: Data) {
        // successfully received message from user
        if self.debug {
            print("STREAMID: \(streamId)\n - DATA: \(data)")
        }
    }
    
        
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurStreamMessageErrorFromUid uid: UInt, streamId: Int, error: Int, missed: Int, cached: Int) {
        // message failed to send(
        if self.debug {
            print("STREAMID: \(streamId)\n - ERROR: \(error)")
        }
    }

}

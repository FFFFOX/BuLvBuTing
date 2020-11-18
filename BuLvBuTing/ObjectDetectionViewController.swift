//
//  ObjectDetectionViewController.swift
//  BuLvBuTing
//
//  Created by Maximus Pro on 2020/10/14.
//

import UIKit
import AVFoundation
import Vision
//import AVKit
import CoreMedia
import WatchConnectivity


class ObjectDetectionViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, WCSessionDelegate {
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    
    // MARK: - Vision Properties
    var request: VNCoreMLRequest?
    var request2: VNCoreMLRequest?
    var OcrRequest: VNRecognizeTextRequest?
    var visionModel: VNCoreMLModel?
    var isInferencing = false
    var audioPlayer:AVAudioPlayer = AVAudioPlayer()
    var alermType: Int = 0
    var path: String = ""
    var numberCountOfCross = 1
    var numberCountOfBlindM = 1
    var numberCountOfBlindL = 1
    var numberCountOfBlindR = 1
    var session: WCSession?
    
    
    // MARK: - AV Property
    var videoCapture: VideoCapture!
    let semaphore = DispatchSemaphore(value: 1)
    
    let videoPreview: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let BoundingBoxView: DrawingBoundingBoxView = {
        let boxView = DrawingBoundingBoxView()
        boxView.translatesAutoresizingMaskIntoConstraints = false
        return boxView
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        setupTabBar()
        setUpModel()
        setupCameraView()
        setUpCamera()
        setupBoundingBoxView()
        createWCSession()
        
    }
    
    func setupTabBar() {
        print("ydw")
        navigationController?.navigationBar.prefersLargeTitles = true
        self.navigationItem.title = "Object Detection"
        if #available(iOS 13.0, *) {
            self.navigationController?.navigationBar.barTintColor = .systemBackground
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor : UIColor.label]
        } else {
            // Fallback on earlier versions
            self.navigationController?.navigationBar.barTintColor = .lightText
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor : UIColor.black]
        }
        self.navigationController?.navigationBar.isHidden = false
        self.setNeedsStatusBarAppearanceUpdate()
        self.navigationItem.largeTitleDisplayMode = .automatic
        self.navigationController?.navigationBar.barStyle = .default
        if #available(iOS 13.0, *) {
            navigationController?.navigationBar.largeTitleTextAttributes = [.foregroundColor : UIColor.label]
        } else {
            navigationController?.navigationBar.largeTitleTextAttributes = [.foregroundColor : UIColor.black]
        }
        if #available(iOS 13.0, *) {
            navigationController?.navigationBar.backgroundColor = .systemBackground
        } else {
            // Fallback on earlier versions
            navigationController?.navigationBar.backgroundColor = .white
        }
        self.tabBarController?.tabBar.isHidden = false
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoCapture.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.videoCapture.stop()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
    
    // MARK: - Setup CoreML model and Text Request recognizer
    func setUpModel() {//
        if let visionModel = try? VNCoreMLModel(for: YDW_C4_3W().model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFill
        } else {
            fatalError("fail to create vision model")
        }
//        if let visionModel2 = try? VNCoreMLModel(for: Road_Sign_Object_Detector_two().model) {
//            self.visionModel = visionModel2
//            request2 = VNCoreMLRequest(model: visionModel2, completionHandler: visionRequestDidComplete)
//            request2?.imageCropAndScaleOption = .scaleFill
//
//        } else {
//            fatalError("fail to create vision model")
//        }
    }
    
    // MARK: - SetUp Camera preview
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 60
        videoCapture.setUp(sessionPreset: .high) { success in
            
            if success {
                // add preview view on the layer
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                
                // start video preview when setup is done
                self.videoCapture.start()
            }
        }
    }
    
    fileprivate func setupCameraView() {
        view.addSubview(videoPreview)
        videoPreview.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        videoPreview.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        videoPreview.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        videoPreview.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
    }
    
    fileprivate func setupBoundingBoxView() {
        view.addSubview(BoundingBoxView)
        BoundingBoxView.bottomAnchor.constraint(equalTo: videoPreview.bottomAnchor).isActive = true
        BoundingBoxView.leftAnchor.constraint(equalTo: videoPreview.leftAnchor).isActive = true
        BoundingBoxView.rightAnchor.constraint(equalTo: videoPreview.rightAnchor).isActive = true
        BoundingBoxView.topAnchor.constraint(equalTo: videoPreview.topAnchor).isActive = true
        
    }
    
}

extension ObjectDetectionViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        // the captured image from camera is contained on pixelBuffer
        if !self.isInferencing, let pixelBuffer = pixelBuffer {
            self.isInferencing = true
            // predict!
            self.predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }
}

extension ObjectDetectionViewController {
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = request else { fatalError() }
        // vision framework configures the input size of image following our model's input configuration automatically which is 416X416
        self.semaphore.wait()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
        
        
        
//        guard let request2 = request2 else { fatalError() }
//        // vision framework configures the input size of image following our model's input configuration automatically which is 416X416
//        self.semaphore.wait()
//        let handler2 = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
//        try? handler2.perform([request2])
    }
    
    // MARK: - Post-processing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if let predictions = request.results as? [VNRecognizedObjectObservation] {
            DispatchQueue.main.async {
                self.BoundingBoxView.predictedObjects = predictions
                self.isInferencing = false
                
                //print(self.BoundingBoxView.predictedObjects)
                self.drawDetectionsOnPreview(detections: predictions)//
                
            }
        } else {
            
            self.isInferencing = false
        }
        self.semaphore.signal()
    }
    //mine
    
    func drawDetectionsOnPreview(detections: [VNRecognizedObjectObservation]) {
        
        //let scale: CGFloat = 0
        for detection in detections {
            
            //print(detection.labels.map({"\($0.identifier)"}).joined(separator: "\n"))
            //            if detection.labels.map({"\($0.identifier)"})[0] == "cross" {
            //                print("斑马线--快跑")
            //
            //                if audioPlayer.isPlaying == false {
            //                    //playAlermVoiceAction()
            //                    playAlermVoiceAction(alermType: 1)
            //                    print("播放音频")
            //                }
            //            }
            switch detection.labels.map({"\($0.identifier)"})[0] {
            case "Cross":
                print("斑马线--快跑")
                if numberCountOfCross == 10 {//计数器保障识别斑马线频率较低
                    if audioPlayer.isPlaying == false {
                        print("--------------播放斑马线音频-------------")
                        playCrossVoiceAction()
                    }
                    numberCountOfCross = 0
                }
                print(numberCountOfCross)
                numberCountOfCross = numberCountOfCross + 1
                
            case "Blind":
                let pos = detection.boundingBox.midX
                if pos >= 0.7 {
                    print("盲道在右边")
//                    if audioPlayer.isPlaying == false {
//                        print("--------------播放右边盲道音频-------------")
//                        //playRBlindVoiceAction()
//                        playRBlindVoiceAction()
//                    }
                    if numberCountOfBlindR == 5 {//计数器保障识别斑马线频率较低
                        if audioPlayer.isPlaying == false {
                            print("--------------播放右边盲道音频-------------")
                            playRBlindVoiceAction()
                        }
                        numberCountOfBlindR = 0
                    }
                    print(numberCountOfBlindR)
                    numberCountOfBlindR = numberCountOfBlindR + 1
                } else if pos <= 0.3 {
                    print("盲道在左边")
//                    if audioPlayer.isPlaying == false {
//                        print("--------------播放左边盲道音频-------------")
//                        //playLBlindVoiceAction()
//                        playLBlindVoiceAction()
//                    }
                    if numberCountOfBlindL == 5 {//计数器保障识别斑马线频率较低
                        if audioPlayer.isPlaying == false {
                            print("--------------播放左边盲道音频-------------")
                            playLBlindVoiceAction()
                        }
                        numberCountOfBlindL = 0
                    }
                    print(numberCountOfBlindL)
                    numberCountOfBlindL = numberCountOfBlindL + 1
                    
                } else {
                    print("盲道在中间")
//                    if audioPlayer.isPlaying == false {
//                        print("--------------播放中间盲道音频-------------")
//                        //playMBlindVoiceAction()
//                        playMBlindVoiceAction()
//                    }
                    if numberCountOfBlindM == 10 {//计数器保障识别斑马线频率较低
                        if audioPlayer.isPlaying == false {
                            print("--------------播放中间盲道音频-------------")
                            playMBlindVoiceAction()
                        }
                        numberCountOfBlindM = 0
                    }
                    print(numberCountOfBlindM)
                    numberCountOfBlindM = numberCountOfBlindM + 1
                    
                }
                
            case "Bike":
//                let pos = detection.boundingBox.midX
//                if pos >= 0.2 && pos <= 0.8 {
//                    print("Bike--快跑")
//                    if audioPlayer.isPlaying == false {
//                        print("--------------播放P14音频-------------")
//                        playP14VoiceAction()
//                    }
//                }
                let pos = detection.boundingBox.midX
                if pos >= 0.7 {
                    print("障碍物在右边")
                    if audioPlayer.isPlaying == false {
                        print("--------------播放右边障碍物音频-------------")
                        //playRBlindVoiceAction()
                        playRbikeVoiceAction()
                    }
                } else if pos <= 0.3 {
                    print("障碍物在左边")
                    if audioPlayer.isPlaying == false {
                        print("--------------播放左边障碍物音频-------------")
                        //playLBlindVoiceAction()
                        playLbikeVoiceAction()
                    }
                } else {
                    print("障碍物在中间")
                    if audioPlayer.isPlaying == false {
                        print("--------------播放中间障碍物音频-------------")
                        //playMBlindVoiceAction()
                        playMbikeVoiceAction()
                        sendDataToWatch()
                    }
                }
                
            case "Glight":
                
                print("Glight--快跑")
                if audioPlayer.isPlaying == false {
                    print("--------------播放Glight音频-------------")
                    playGlightVoiceAction()
                }
                
            case "Rlight":
                
                print("Rlight--快跑")
                if audioPlayer.isPlaying == false {
                    print("--------------播放Rlight音频-------------")
                    playRlightVoiceAction()
                    sendDataToWatch()
                }
                
//                print("P14--快跑")
//                if audioPlayer.isPlaying == false {
//                    print("--------------播放P14音频-------------")
//                    playP14VoiceAction()
//                }
            default:
                print("无可识别Label")
            }
            
            print(detection.boundingBox.width)
            print(detection.boundingBox.height)
            //print(detection.boundingBox.minX)
            print("所处位置：\(detection.boundingBox.midX)")
            //print(detection.boundingBox.maxX)
            print("------------")
            
            //            The coordinates are normalized to the dimensions of the processed image, with the origin at the image's lower-left corner.
        }
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
    }
    
    func playCrossVoiceAction(){
        print("运行音频函数")
        let session = AVAudioSession.sharedInstance()
        do{
            try session.setActive(true)
            try session.setCategory(AVAudioSession.Category.playback)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            let path = Bundle.main.path(forResource: "Cross", ofType: "mp3")
            let soudUrl = URL(fileURLWithPath: path!)
            try audioPlayer = AVAudioPlayer(contentsOf: soudUrl, fileTypeHint: AVFileType.mp3.rawValue)
            audioPlayer.prepareToPlay()
            audioPlayer.volume = 2
            audioPlayer.numberOfLoops = 0
            audioPlayer.enableRate = true
            audioPlayer.rate = 2.0
            audioPlayer.play()

        } catch{
            print(error)
        }
    }
    
    func playP14VoiceAction(){
        print("运行音频函数")
        let session = AVAudioSession.sharedInstance()
        do{
            try session.setActive(true)
            try session.setCategory(AVAudioSession.Category.playback)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            let path = Bundle.main.path(forResource: "P14tts", ofType: "mp3")
            let soudUrl = URL(fileURLWithPath: path!)
            try audioPlayer = AVAudioPlayer(contentsOf: soudUrl, fileTypeHint: AVFileType.mp3.rawValue)
            audioPlayer.prepareToPlay()
            audioPlayer.volume = 2
            audioPlayer.numberOfLoops = 0
            audioPlayer.enableRate = true
            audioPlayer.rate = 2.0
            audioPlayer.play()
            
        } catch{
            print(error)
        }
    }
    
    func playLBlindVoiceAction(){
        print("运行音频函数")
        let session = AVAudioSession.sharedInstance()
        do{
            try session.setActive(true)
            try session.setCategory(AVAudioSession.Category.playback)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            let path = Bundle.main.path(forResource: "LBlind2", ofType: "mp3")
            let soudUrl = URL(fileURLWithPath: path!)
            try audioPlayer = AVAudioPlayer(contentsOf: soudUrl, fileTypeHint: AVFileType.mp3.rawValue)
            audioPlayer.prepareToPlay()
            audioPlayer.volume = 2
            audioPlayer.numberOfLoops = 0
            audioPlayer.enableRate = true
            audioPlayer.rate = 2.0
            audioPlayer.play()
            
        } catch{
            print(error)
        }
    }
    
    func playRBlindVoiceAction(){
        print("运行音频函数")
        let session = AVAudioSession.sharedInstance()
        do{
            try session.setActive(true)
            try session.setCategory(AVAudioSession.Category.playback)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            let path = Bundle.main.path(forResource: "RBlind2", ofType: "mp3")
            let soudUrl = URL(fileURLWithPath: path!)
            try audioPlayer = AVAudioPlayer(contentsOf: soudUrl, fileTypeHint: AVFileType.mp3.rawValue)
            audioPlayer.prepareToPlay()
            audioPlayer.volume = 2
            audioPlayer.numberOfLoops = 0
            audioPlayer.enableRate = true
            audioPlayer.rate = 2.0
            audioPlayer.play()
            
        } catch{
            print(error)
        }
    }
    
    func playMBlindVoiceAction(){
        print("运行音频函数")
        let session = AVAudioSession.sharedInstance()
        do{
            try session.setActive(true)
            try session.setCategory(AVAudioSession.Category.playback)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            let path = Bundle.main.path(forResource: "Mtts", ofType: "mp3")
            let soudUrl = URL(fileURLWithPath: path!)
            try audioPlayer = AVAudioPlayer(contentsOf: soudUrl, fileTypeHint: AVFileType.mp3.rawValue)
            audioPlayer.prepareToPlay()
            audioPlayer.volume = 2
            audioPlayer.numberOfLoops = 0
            audioPlayer.enableRate = true
            audioPlayer.rate = 2.0
            audioPlayer.play()
            
        } catch{
            print(error)
        }
    }
    
    func playGlightVoiceAction(){
        print("运行音频函数")
        let session = AVAudioSession.sharedInstance()
        do{
            try session.setActive(true)
            try session.setCategory(AVAudioSession.Category.playback)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            let path = Bundle.main.path(forResource: "Glight", ofType: "mp3")
            let soudUrl = URL(fileURLWithPath: path!)
            try audioPlayer = AVAudioPlayer(contentsOf: soudUrl, fileTypeHint: AVFileType.mp3.rawValue)
            audioPlayer.prepareToPlay()
            audioPlayer.volume = 2
            audioPlayer.numberOfLoops = 0
            audioPlayer.enableRate = true
            audioPlayer.rate = 2.0
            audioPlayer.play()
            
        } catch{
            print(error)
        }
    }
    
    func playRlightVoiceAction(){
        print("运行音频函数")
        let session = AVAudioSession.sharedInstance()
        do{
            try session.setActive(true)
            try session.setCategory(AVAudioSession.Category.playback)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            let path = Bundle.main.path(forResource: "Rlight", ofType: "mp3")
            let soudUrl = URL(fileURLWithPath: path!)
            try audioPlayer = AVAudioPlayer(contentsOf: soudUrl, fileTypeHint: AVFileType.mp3.rawValue)
            audioPlayer.prepareToPlay()
            audioPlayer.volume = 2
            audioPlayer.numberOfLoops = 0
            audioPlayer.enableRate = true
            audioPlayer.rate = 2.0
            audioPlayer.play()
            
        } catch{
            print(error)
        }
    }
    
    func playRbikeVoiceAction(){
        print("运行音频函数")
        let session = AVAudioSession.sharedInstance()
        do{
            try session.setActive(true)
            try session.setCategory(AVAudioSession.Category.playback)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            let path = Bundle.main.path(forResource: "Rbike2", ofType: "mp3")
            let soudUrl = URL(fileURLWithPath: path!)
            try audioPlayer = AVAudioPlayer(contentsOf: soudUrl, fileTypeHint: AVFileType.mp3.rawValue)
            audioPlayer.prepareToPlay()
            audioPlayer.volume = 2
            audioPlayer.numberOfLoops = 0
            audioPlayer.enableRate = true
            audioPlayer.rate = 2.0
            audioPlayer.play()
            
        } catch{
            print(error)
        }
    }
    
    func playLbikeVoiceAction(){
        print("运行音频函数")
        let session = AVAudioSession.sharedInstance()
        do{
            try session.setActive(true)
            try session.setCategory(AVAudioSession.Category.playback)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            let path = Bundle.main.path(forResource: "Lbike2", ofType: "mp3")
            let soudUrl = URL(fileURLWithPath: path!)
            try audioPlayer = AVAudioPlayer(contentsOf: soudUrl, fileTypeHint: AVFileType.mp3.rawValue)
            audioPlayer.prepareToPlay()
            audioPlayer.volume = 2
            audioPlayer.numberOfLoops = 0
            audioPlayer.enableRate = true
            audioPlayer.rate = 2.0
            audioPlayer.play()
            
        } catch{
            print(error)
        }
    }
    
    func playMbikeVoiceAction(){
        print("运行音频函数")
        let session = AVAudioSession.sharedInstance()
        do{
            try session.setActive(true)
            try session.setCategory(AVAudioSession.Category.playback)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            let path = Bundle.main.path(forResource: "Mbike", ofType: "mp3")
            let soudUrl = URL(fileURLWithPath: path!)
            try audioPlayer = AVAudioPlayer(contentsOf: soudUrl, fileTypeHint: AVFileType.mp3.rawValue)
            audioPlayer.prepareToPlay()
            audioPlayer.volume = 2
            audioPlayer.numberOfLoops = 0
            audioPlayer.enableRate = true
            audioPlayer.rate = 2.0
            audioPlayer.play()
            
        } catch{
            print(error)
        }
    }
    
    func createWCSession() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    func sendDataToWatch() {
        if let validSession = self.session, validSession.isReachable {
//            validSession.sendMessage(["iPhone": phoneLabel.text!], replyHandler: nil, errorHandler: nil)
            validSession.sendMessage(["iPhone": "Like"], replyHandler: nil, errorHandler: nil)
        }
    }
    
}

//extension ViewController: WCSessionDelegate {
//    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
//    }
//    func sessionDidBecomeInactive(_ session: WCSession) {
//    }
//    func sessionDidDeactivate(_ session: WCSession) {
//    }
//}

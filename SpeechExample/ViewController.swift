//
//  ViewController.swift
//  SpeechExample
//
//  Created by Eric Larson on 10/28/20.
//

import UIKit
import AVFoundation
import Speech


// starter code used from https://github.com/darjeelingsteve/speech-recognition

class ViewController: UIViewController {

    // MARK: Properties
    // The speech recogniser used by the controller to record the user's speech.
    private let speechRecogniser = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        
    // The current speech recognition request. Created when the user wants to begin speech recognition
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
        
    // The current speech recognition task. Created when the user wants to begin speech recognition.
    private var recognitionTask: SFSpeechRecognitionTask?
        
    // The audio engine used to record input from the microphone.
    private let audioEngine = AVAudioEngine()

    // MARK: UI LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // can also be changed at runtime via storyBoard!!
        //self.dictation.layer.masksToBounds = true
        //self.dictation.layer.cornerRadius = 2
    }
    
    // MARK: SFAudioTranscription
    func startRecording() {
        // setup recongizer
        guard speechRecogniser.isAvailable else {
            // Speech recognition is unavailable, so do not attempt to start.
            return
        }
        
        // make sure we have permission
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            SFSpeechRecognizer.requestAuthorization({ (status) in
                // Handle the user's decision
                print(status)
            })
            return
        }
        
        
        // setup audio
        let audioSession = AVAudioSession.sharedInstance()
        do{
            try audioSession.setCategory(AVAudioSession.Category.record)
            try audioSession.setMode(AVAudioSession.Mode.measurement)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        }
        catch {
            fatalError("Audio engine could not be setup")
            
        }

        if recognitionRequest == nil {
            // setup reusable request (if not already)
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            // perform on device, if possible
            // NOTE: this will usually limit the voice analytics results
            if speechRecogniser.supportsOnDeviceRecognition {
                print("Using on device recognition, voice analytics may be limited.")
                recognitionRequest?.requiresOnDeviceRecognition = true
            }else{
                print("Using server for recognition.")
            }
        }
        

        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else {
            // Handle error
            return
        }
        
        recognitionTask = speechRecogniser.recognitionTask(with: recognitionRequest) { [unowned self] result, error in
            if let result = result {
                let spokenText = result.bestTranscription.formattedString
                DispatchQueue.main.async{
                    // fill in the label here
                    self.dictation.text = spokenText
                }
            }
            
            if result?.isFinal ?? (error != nil) {
                // this will remove the listening tap
                // so that the transcription stops
                inputNode.removeTap(onBus: 0)
                print(result!)
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do{
            try audioEngine.start()
        }
        catch {
            fatalError("Audio engine could not start")
        }
    }
    
    func stopRecording() {
        if audioEngine.isRunning{
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
    }

    // MARK: UI Elements
    @IBAction func recordingPressed(_ sender: UIButton) {
        // set button to display "recording"
        sender.setImage(UIImage(systemName: "mic.circle.fill"), for: .normal)
        sender.backgroundColor = UIColor.gray
        
        self.startRecording()

    }
    
    
    @IBAction func recordingReleased(_ sender: UIButton) {
        self.stopRecording()
        
        // set button to display "normal"
        sender.setImage(UIImage(systemName: "mic.circle"), for: .normal)
        sender.backgroundColor = UIColor.white
    }
    
    @IBOutlet weak var dictation: UILabel!
}


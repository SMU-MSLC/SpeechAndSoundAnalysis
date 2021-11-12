//
//  ViewController.swift
//  SpeechExample
//
//  Created by Eric Larson on 10/28/20.
//

import UIKit
import AVFoundation
import Speech
import SoundAnalysis

// ======================================================
// MUST be using iOS15+ to access the sound analyzer code
// ======================================================
// combined the codes from the following places:
// starter code used from https://github.com/darjeelingsteve/speech-recognition
// From apple: https://developer.apple.com/documentation/soundanalysis/classifying_sounds_in_an_audio_file

class ViewController: UIViewController {

    // MARK: Speech Properties
    /// The speech recogniser used by the controller to record the user's speech.
    private let speechRecogniser = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        
    /// The current speech recognition request. Created when the user wants to begin speech recognition
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
        
    /// The current speech recognition task. Created when the user wants to begin speech recognition.
    private var recognitionTask: SFSpeechRecognitionTask?
        
    /// The audio engine used to record input from the microphone.
    private let audioEngine = AVAudioEngine()
    
    
    // MARK: Sound Analyzer Properties
    /// The request we qill use for the cound classifier
    var soundRequest:SNClassifySoundRequest? = nil
    /// A background analysis queue we will use for machine learning
    let analysisQueue = DispatchQueue(label: "com.example.AnalysisQueue")
    /// The stream analyzer we use as part of the recognition request
    var streamAnalyzer:SNAudioStreamAnalyzer? = nil
    
    // MARK: UI LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // MARK: One Setup Built-In Sound Classifier Model
        let version1 = SNClassifierIdentifier.version1
        do{
            self.soundRequest = try SNClassifySoundRequest(classifierIdentifier: version1)
            
        }catch{
            fatalError("Sound Request (version1) could not be setup")
        }

    }
    
    // MARK: SFAudioTranscription
    func startRecording() {
        // setup speech recongizer
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
        
        
        // setup audio for recording
        let audioSession = AVAudioSession.sharedInstance()
        do{
            try audioSession.setCategory(AVAudioSession.Category.record)
            try audioSession.setMode(AVAudioSession.Mode.measurement)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        }
        catch {
            fatalError("Audio engine could not be setup")
            
        }
        
        

        // setup reusable request
        if recognitionRequest == nil {
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
        
        // MARK: Two Setup Audio Stream Analyzer
        /// This sets up the sound classifier to incrementally try and classify windows of sound. It also defines what will happen when a sucessful classification occurs (it will call the delegate for SNObserver, which is self)
        // if we have not setup the classifier to output recognition results
        if self.streamAnalyzer == nil {
            do{
                // Create a new stream analyzer.
                self.streamAnalyzer = SNAudioStreamAnalyzer(format: inputNode.inputFormat(forBus: 0))
                // Add a sound classification request that reports to an observer.
                try streamAnalyzer?.add(self.soundRequest!,
                                    withObserver: self)
            }catch{
                fatalError("Could not attach sound classifier stream")
            }
        }
        
        // setup how to handle the speech recognition result
        recognitionTask = speechRecogniser.recognitionTask(with: recognitionRequest) { [unowned self] result, error in
            if let result = result {
                let spokenText = result.bestTranscription.formattedString
                DispatchQueue.main.async{
                    // fill in the label here
                    self.dictation.text = spokenText
                }
            }
            // stop listening if the result is final or ended for whatever reason
            if result?.isFinal ?? (error != nil) {
                // this will remove the listening tap
                // so that the transcription stops
                inputNode.removeTap(onBus: 0)
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            // here we add the audio buffer directly into the recognition request
            self.recognitionRequest?.append(buffer)
            
            // MARK: Three Analyze buffers of audio
            // here we try to classify the audio stream for classification
            self.analysisQueue.async {
                // perform on bakcground thread as this classifier can take a bit of time
                self.streamAnalyzer!.analyze(buffer,
                                atAudioFramePosition: when.sampleTime)
            }
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

/// An observer that receives results from a classify sound request.
extension ViewController: SNResultsObserving {
    /// Notifies the observer when a request generates a prediction.
    func request(_ request: SNRequest, didProduce result: SNResult) {
        // Downcast the result to a classification result.
        guard let result = result as? SNClassificationResult else  { return }

        // Get the prediction with the highest confidence.
        guard let classification = result.classifications.first else { return }

        // Get the starting time.
        let timeInSeconds = result.timeRange.start.seconds

        // Convert the time to a human-readable string.
        let formattedTime = String(format: "%.2f", timeInSeconds)
        print("Analysis result for audio at time: \(formattedTime)")

        // Convert the confidence to a percentage string.
        let percent = classification.confidence * 100.0
        let percentString = String(format: "%.2f%%", percent)

        // Print the classification's name (label) with its confidence.
        print("\(classification.identifier): \(percentString) confidence.\n")
    }


    /// Notifies the observer when a request generates an error.
    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("The the analysis failed: \(error.localizedDescription)")
    }

    /// Notifies the observer when a request is complete.
    func requestDidComplete(_ request: SNRequest) {
        print("The request completed successfully!")
    }
}


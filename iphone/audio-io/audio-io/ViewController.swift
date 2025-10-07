import UIKit
import AVFoundation
import UniformTypeIdentifiers

class ViewController: UIViewController, UIDocumentPickerDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!

    // MARK: - Audio Properties
    var audioPlayer: AVAudioPlayer?
    var audioRecorder: AVAudioRecorder?
    var selectedSongURL: URL?
    var isPlaying = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // Initial setup for the audio session
        setupAudioSession()
        playButton.isEnabled = false // Disable play button until a file is selected
    }

    // MARK: - Audio Session Setup
    func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Set the category to play and record to allow simultaneous playback and recording.
            try audioSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    // MARK: - IBActions
    @IBAction func selectFileTapped(_ sender: Any) {
        // Open the document picker to select an audio file from the Files app.
        // We ask for a copy so our app has persistent access to it.
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio], asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true, completion: nil)
    }

    @IBAction func playTapped(_ sender: Any) {
        if isPlaying {
            stopPlaybackAndRecording()
        } else {
            startPlaybackAndRecording()
        }
    }

    // MARK: - Document Picker Delegate
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // This function is called when the user selects a file.
        guard let url = urls.first else {
            return
        }
        
        // The URL is a copy in our app's temp directory, so we can use it directly.
        self.selectedSongURL = url
        self.fileNameLabel.text = url.deletingPathExtension().lastPathComponent
        self.playButton.isEnabled = true
        self.preparePlayer()
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // This is called if the user cancels the selection.
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Core Logic
    func preparePlayer() {
        guard let url = selectedSongURL else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            // Set numberOfLoops to -1 for infinite looping
            audioPlayer?.numberOfLoops = -1
        } catch {
            print("Error creating audio player: \(error)")
        }
    }

    func startPlaybackAndRecording() {
        guard audioPlayer != nil else {
            print("Audio player not ready.")
            return
        }
        
        // Start playing
        audioPlayer?.play()
        
        // Start recording
        startRecording()
        
        isPlaying = true
        playButton.setTitle("Stop", for: .normal)
    }

    func stopPlaybackAndRecording() {
        // Stop playing
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0 // Rewind to the beginning
        
        // Stop recording
        stopRecording()
        
        isPlaying = false
        playButton.setTitle("Play and Record", for: .normal)
    }

    // MARK: - Recording Logic
    func startRecording() {
        let recordingName = "recording.wav"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(recordingName)

        // Recording settings for two-channel (stereo) audio
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2, // Two channels for stereo
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.record()
            print("Recording started. File saved at: \(audioURL.path)")
        } catch {
            print("Could not start recording: \(error)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        print("Recording stopped.")
    }
}


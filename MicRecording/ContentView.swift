import Foundation
import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject var audioRecorder = AudioRecorder()
    @StateObject var audioEngine = AudioEngine()
    @StateObject var audioCaptureRecording = AudioCapture()
    @StateObject var audioCaptureStreaming = AudioCapture()

    @State private var selectedDeviceInput: String = "<None>"
    
    var audioInputDevices: [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone],
                                                                mediaType: .audio,
                                                                position: .unspecified)
        return discoverySession.devices
    }
    
    var selectedAudioInputDevice: AVCaptureDevice? {
        audioInputDevices.first { $0.uniqueID == selectedDeviceInput }
    }
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            HStack {
                VStack {
                    AudioLevelsView(audioLevels: audioRecorder.audioLevels)
                    HStack {
                        if audioRecorder.state == .stopped {
                            Button {
                                audioRecorder.record()
                            } label: {
                                Text("Start Recording")
                            }
                        } else {
                            Button {
                                audioRecorder.stopRecording()
                            } label: {
                                Text("Stop Recording")
                            }
                        }
                    }
                }
                
                VStack {
                    AudioLevelsView(audioLevels: audioEngine.audioLevels)
                    HStack {
                        if audioEngine.state == .stopped {
                            Button {
                                audioEngine.startStreaming()
                            } label: {
                                Text("Start Streaming")
                            }
                        } else {
                            Button {
                                audioEngine.stopStreaming()
                            } label: {
                                Text("Stop Streaming")
                            }
                        }
                    }
                }
            }
            Form {
                Picker("Input Devices", selection: $selectedDeviceInput) {
                    Text("<None>").tag("<None>")
                    ForEach(audioInputDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }
                
            }
            if let selectedAudioInputDevice = selectedAudioInputDevice  {
                HStack {
                    VStack {
                        AudioLevelsView(audioLevels: audioCaptureRecording.audioLevels)
                        HStack {
                            if audioCaptureRecording.state == .stopped {
                                Button {
                                    Task {
                                        await audioCaptureRecording.startRecording(audioDevice: selectedAudioInputDevice)
                                    }
                                } label: {
                                    Text("Start Recording")
                                }
                            } else {
                                Button {
                                    audioCaptureRecording.stopRecording()
                                } label: {
                                    Text("Stop Recording")
                                }
                            }
                        }
                    }
                    
                    VStack {
                        AudioLevelsView(audioLevels: audioCaptureStreaming.audioLevels)
                        HStack {
                            if audioCaptureStreaming.state == .stopped {
                                Button {
                                    Task {
                                        await audioCaptureStreaming.startStream(audioDevice: selectedAudioInputDevice)
                                    }
                                } label: {
                                    Text("Start Streaming")
                                }
                            } else {
                                Button {
                                    audioCaptureStreaming.stopStreaming()
                                } label: {
                                    Text("Stop Streaming")
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
    
}

#Preview {
    ContentView()
}

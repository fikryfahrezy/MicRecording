import Foundation
import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject var audioRecorder = AudioRecorder()
    @StateObject var audioEngine = AudioEngine()
    private let ade = AudioDeviceEnumerator()
    
    @State private var selectedDeviceInput: AudioDeviceID?
    
    var audioInputDevices: [AudioDeviceEnumerator.Device] {
        return ade.listDevices().filter { $0.input != 0 }
    }
    
    var audioOutputDevices: [AudioDeviceEnumerator.Device] {
        ade.listDevices().filter { $0.output != 0 }
    }

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Form {
                Picker("Input Devices", selection: $selectedDeviceInput) {
                    ForEach(audioInputDevices, id: \.deviceID) { device in
                        Text(device.name).tag(device.deviceID)
                    }
                }
                
            }
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
        }
        .padding()
    }
    
}

#Preview {
    ContentView()
}

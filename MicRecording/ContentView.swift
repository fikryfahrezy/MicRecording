import Foundation
import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject var audioRecorder = AudioRecorder()
    @StateObject var audioEngine = AudioEngine()
    
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
        }
        .padding()
    }
    
}

#Preview {
    ContentView()
}

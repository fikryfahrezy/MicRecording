import Foundation
import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject var audioRecorder = AudioRecorder()
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            AudioLevelsView(audioLevels: audioRecorder.audioLevels)
            HStack {
                if audioRecorder.state == .stopped {
                    Button {
                        audioRecorder.record()
                    } label: {
                        Text("Start")
                    }
                } else {
                    Button {
                        audioRecorder.stopRecording()
                    } label: {
                        Text("Stop")
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

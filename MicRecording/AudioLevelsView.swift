import Foundation
import SwiftUI

struct AudioLevelsView: NSViewRepresentable {
    
    var audioLevels: AudioLevels
    
    func makeNSView(context: Context) -> NSLevelIndicator {
        let levelIndicator = NSLevelIndicator(frame: .zero)
        levelIndicator.minValue = 0
        levelIndicator.maxValue = 10
        levelIndicator.warningValue = 6
        levelIndicator.criticalValue = 8
        levelIndicator.levelIndicatorStyle = .continuousCapacity
        levelIndicator.heightAnchor.constraint(equalToConstant: 5).isActive = true
        return levelIndicator
    }
    
    func updateNSView(_ levelMeter: NSLevelIndicator, context: Context) {
        levelMeter.floatValue = audioLevels.average * 10
    }
}

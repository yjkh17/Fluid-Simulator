//
//  DisplayLinkTimer.swift
//  Fluid Simulator
//
//  Created by Yousef Jawdat on 06/06/2025.
//

import Foundation
import QuartzCore

class DisplayLinkTimer: ObservableObject {
    private var displayLink: CADisplayLink?
    private var lastUpdateTime: TimeInterval = 0
    private let updateCallback: (TimeInterval) -> Void
    
    init(updateCallback: @escaping (TimeInterval) -> Void) {
        self.updateCallback = updateCallback
    }
    
    func start() {
        guard displayLink == nil else { return }
        
        lastUpdateTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func update() {
        let currentTime = CACurrentMediaTime()
        var deltaTime = currentTime - lastUpdateTime
        deltaTime = min(deltaTime, 0.016666) // Limit to ~60fps like original
        lastUpdateTime = currentTime
        
        updateCallback(deltaTime)
    }
}
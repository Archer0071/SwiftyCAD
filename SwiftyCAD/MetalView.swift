//
//  MetalView.swift
//  Pipes
//
//  Created by Adil Hanif on 6/14/25.
//

import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {
    let rendererState: RendererState
    private let renderer = CADRenderer()
    
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.clearColor = MTLClearColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        view.delegate = renderer
        view.depthStencilPixelFormat = .depth32Float
        renderer.mtkView = view
        
        // Set up notifications
        NotificationCenter.default.addObserver(
            forName: .addObjectToScene,
            object: nil,
            queue: .main
        ) { notification in
            if let object = notification.object as? SceneObject {
                self.renderer.addObject(object)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .toggleProjectionMode,
            object: nil,
            queue: .main
        ) { _ in
            self.renderer.toggleProjectionMode()
        }
        
        // Gestures
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(doubleTap)
        
        return view
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update projection mode if changed
        renderer.isOrthographic = rendererState.isOrthographic
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer)
    }
    
    class Coordinator: NSObject {
        var renderer: CADRenderer
        var previousTranslation: CGPoint = .zero
        var selectedAxis: CADRenderer.MovementAxis = .none
        
        init(renderer: CADRenderer) {
            self.renderer = renderer
        }
        
        @objc func handlePan(_ sender: UIPanGestureRecognizer) {
            let translation = sender.translation(in: sender.view)
            let deltaX = Float(translation.x - previousTranslation.x) * 0.01
            let deltaY = Float(translation.y - previousTranslation.y) * 0.01
            
            if sender.state == .began {
                // When pan starts, detect if we're touching an axis
                let location = sender.location(in: sender.view)
                selectedAxis = renderer.detectMovementAxis(at: location, in: sender.view as! MTKView)
            }
            
            if sender.numberOfTouches == 1 {
                if selectedAxis != .none {
                    // Move object along selected axis
                    let movementVector = SIMD3<Float>(deltaX, -deltaY, 0)
                    renderer.moveSelectedObject(translation: movementVector, along: selectedAxis)
                } else {
                    // Rotate camera if not moving an object
                    renderer.camera.rotate(deltaX: deltaX, deltaY: deltaY)
                }
            } else if sender.numberOfTouches == 2 {
                // Pan camera with two fingers
                renderer.camera.pan(deltaX: deltaX, deltaY: deltaY)
            }
            
            previousTranslation = translation
            
            if sender.state == .ended {
                previousTranslation = .zero
                selectedAxis = .none
            }
        }
        
        @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
            let delta = Float(1 - sender.scale) * 0.5
            renderer.camera.zoom(delta: delta)
            sender.scale = 1
        }
        
        @objc func handleDoubleTap(_ sender: UITapGestureRecognizer) {
            let location = sender.location(in: sender.view)
            renderer.selectObject(at: location, in: sender.view as! MTKView)
        }
    }
}

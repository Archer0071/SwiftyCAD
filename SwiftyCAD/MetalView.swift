//
//  MetalView.swift
//  Pipes
//
//  Created by Adil Hanif on 6/14/25.
//

import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {
    @ObservedObject var rendererState: RendererState
    private let renderer: CADRenderer
    
    init(rendererState: RendererState) {
        self.rendererState = rendererState
        self.renderer = CADRenderer()
    }
    
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        view.device = device
        view.clearColor = MTLClearColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        view.delegate = renderer
        view.depthStencilPixelFormat = .depth32Float
        view.colorPixelFormat = .bgra8Unorm
        renderer.mtkView = view
        
        // Add gesture recognizers
        setupGestureRecognizers(for: view, context: context)
        
        // Add tap recognizer
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        
        setupNotificationObservers()
        
        return view
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        renderer.isOrthographic = rendererState.isOrthographic
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer,rendererState: rendererState)
    }
    
    private func setupGestureRecognizers(for view: MTKView, context: Context) {
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 2
        
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .addObjectToScene,
            object: nil,
            queue: .main
        ) { notification in
            guard let object = notification.object as? SceneObject else { return }
            self.renderer.addObject(object)
        }
    }
    
    class Coordinator: NSObject {
        private weak var renderer: CADRenderer?
        private weak var rendererState: RendererState?
        private var previousTranslation: CGPoint = .zero
        private var selectedAxis: CADRenderer.MovementAxis = .none
        
        init(renderer: CADRenderer, rendererState: RendererState) {
            self.renderer = renderer
            self.rendererState = rendererState
        }
        
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let view = sender.view as? MTKView,
                  let renderer = renderer,
                  let rendererState = rendererState else { return }
            
            let location = sender.location(in: view)
            renderer.selectObject(at: location, in: view)
            
            if let selectedID = renderer.selectedObjectID,
               let selectedObject = renderer.sceneObjects.first(where: { $0.id == selectedID }) {
                rendererState.selectedObject = selectedObject
            } else {
                rendererState.selectedObject = nil
            }
        }
        
        @objc func handlePan(_ sender: UIPanGestureRecognizer) {
            guard let view = sender.view as? MTKView, let renderer = renderer else { return }
            
            let translation = sender.translation(in: view)
            let deltaX = Float(translation.x - previousTranslation.x)
            let deltaY = Float(translation.y - previousTranslation.y)
            
            switch sender.state {
            case .began:
                let location = sender.location(in: view)
                selectedAxis = renderer.detectMovementAxis(at: location, in: view)
                previousTranslation = translation
                
            case .changed:
                if sender.numberOfTouches == 1 {
                    if selectedAxis != .none {
                        // Scale the movement for better control
                        let movementScale: Float = 0.01
                        let movementVector = SIMD3<Float>(deltaX * movementScale, -deltaY * movementScale, 0)
                        renderer.moveSelectedObject(translation: movementVector, along: selectedAxis)
                    } else {
                        // Camera rotation
                        let rotationScale: Float = 0.005
                        renderer.camera.rotate(deltaX: deltaX * rotationScale, deltaY: deltaY * rotationScale)
                    }
                } else if sender.numberOfTouches == 2 {
                    // Camera pan
                    let panScale: Float = 0.005
                    renderer.camera.pan(deltaX: deltaX * panScale, deltaY: deltaY * panScale)
                }
                previousTranslation = translation
                
            case .ended, .cancelled:
                previousTranslation = .zero
                selectedAxis = .none
                
            default:
                break
            }
        }
        
        @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
            guard let renderer = renderer, sender.state == .changed else { return }
            let delta = Float(1 - sender.scale) * 0.5
            renderer.camera.zoom(delta: delta)
            sender.scale = 1
        }
    }
}

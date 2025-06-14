//
//  RenderState.swift
//  Pipes
//
//  Created by Adil Hanif on 6/14/25.
//

import Foundation
import simd

class RendererState: ObservableObject {
    @Published var isOrthographic = false
    
    func addShape(_ type: ObjectType) {
        let position: SIMD3<Float>
        let scale: SIMD3<Float>
        
        switch type {
        case .cube:
            position = [0, 0.5, 0]
            scale = [1, 1, 1]
        case .sphere:
            position = [0, 0.5, 0]
            scale = [1, 1, 1]
        case .cylinder:
            position = [0, 0.75, 0]
            scale = [1, 1.5, 1]
        }
        
        let newObject = SceneObject(type: type, position: position, scale: scale)
        NotificationCenter.default.post(name: .addObjectToScene, object: newObject)
    }
    
    func toggleProjection() {
        isOrthographic.toggle()
        NotificationCenter.default.post(name: .toggleProjectionMode, object: nil)
    }
}

extension Notification.Name {
    static let addObjectToScene = Notification.Name("AddObjectToScene")
    static let toggleProjectionMode = Notification.Name("ToggleProjectionMode")
}

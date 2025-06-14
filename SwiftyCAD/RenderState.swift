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
    @Published var selectedObject: SceneObject?
    
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
        selectedObject = newObject
        NotificationCenter.default.post(name: .addObjectToScene, object: newObject)
    }
    
    func toggleProjection() {
        isOrthographic.toggle()
    }
    
    func updateSelectedObjectPosition(_ position: SIMD3<Float>) {
        guard let selected = selectedObject else { return }
        selected.position = position
        NotificationCenter.default.post(name: .updateObjectPosition, object: selected)
    }
    func updateSelectedObjectRotation(_ rotation: SIMD3<Float>) {
        guard let selected = selectedObject else { return }
        selected.rotation = rotation
        NotificationCenter.default.post(name: .updateObjectRotation, object: selected)
    }
}

extension Notification.Name {
    static let addObjectToScene = Notification.Name("AddObjectToScene")
    static let toggleProjectionMode = Notification.Name("ToggleProjectionMode")
    static let updateObjectPosition = Notification.Name("UpdateObjectPosition")
    static let updateObjectRotation = Notification.Name("UpdateObjectRotation")

}

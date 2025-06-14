//
//  Renderer.swift
//  Pipes
//
//  Created by Adil Hanif on 6/14/25.
//


import MetalKit
import simd

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
    
    var xy: SIMD2<Float> {
        return SIMD2<Float>(x, y)
    }
}
class CADRenderer: NSObject, MTKViewDelegate {
    // MARK: - Core Properties
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    var gridPipelineState: MTLRenderPipelineState!
    var axisPipelineState: MTLRenderPipelineState!
    var depthStencilState: MTLDepthStencilState!
    var gizmoPipelineState: MTLRenderPipelineState!
    
    // Geometry Buffers
    var vertexBuffers: [String: MTLBuffer] = [:]
    var indexBuffers: [String: MTLBuffer] = [:]
    
    // Scene Management
    var mtkView: MTKView?
    var sceneObjects: [SceneObject] = []
    var selectedObjectID: UUID?
    
    // View Settings
    var camera = Camera()
    var isOrthographic = false
    var gridSize: Float = 10
    var gridDivisions: Int = 10
    
    init(mtkView: MTKView? = nil) {
        self.mtkView = mtkView
        super.init()
        setupMetal()
        setupScene()
    }
    
    // MARK: - Setup Methods
    func setupMetal() {
        // Initialize Metal components
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        
        // Setup depth state
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthDescriptor)!
        
        // Create pipelines
        createPipelines()
        
        // Generate geometry
        createPrimitives()
    }
    
    func createPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Unable to create default Metal library")
        }
        
        // 1. Common vertex descriptor for simple geometry (position only)
        let positionVertexDescriptor = MTLVertexDescriptor()
        positionVertexDescriptor.attributes[0].format = .float3
        positionVertexDescriptor.attributes[0].offset = 0
        positionVertexDescriptor.attributes[0].bufferIndex = 0
        positionVertexDescriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
        positionVertexDescriptor.layouts[0].stepRate = 1
        positionVertexDescriptor.layouts[0].stepFunction = .perVertex
        
        // 2. Vertex descriptor for gizmo (position + color)
        let gizmoVertexDescriptor = MTLVertexDescriptor()
        // Position attribute
        gizmoVertexDescriptor.attributes[0].format = .float3
        gizmoVertexDescriptor.attributes[0].offset = 0
        gizmoVertexDescriptor.attributes[0].bufferIndex = 0
        // Color attribute
        gizmoVertexDescriptor.attributes[1].format = .float4
        gizmoVertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        gizmoVertexDescriptor.attributes[1].bufferIndex = 0
        // Layout
        gizmoVertexDescriptor.layouts[0].stride = MemoryLayout<GizmoVertex>.stride
        gizmoVertexDescriptor.layouts[0].stepRate = 1
        gizmoVertexDescriptor.layouts[0].stepFunction = .perVertex
        
        // Main object pipeline (position only)
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_main")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.vertexDescriptor = positionVertexDescriptor
        
        // Grid pipeline (position only)
        let gridDescriptor = MTLRenderPipelineDescriptor()
        gridDescriptor.vertexFunction = library.makeFunction(name: "grid_vertex")
        gridDescriptor.fragmentFunction = library.makeFunction(name: "grid_fragment")
        gridDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        gridDescriptor.depthAttachmentPixelFormat = .depth32Float
        gridDescriptor.vertexDescriptor = positionVertexDescriptor
        
        // Axis pipeline (position only)
        let axisDescriptor = MTLRenderPipelineDescriptor()
        axisDescriptor.vertexFunction = library.makeFunction(name: "axis_vertex")
        axisDescriptor.fragmentFunction = library.makeFunction(name: "axis_fragment")
        axisDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        axisDescriptor.depthAttachmentPixelFormat = .depth32Float
        axisDescriptor.vertexDescriptor = positionVertexDescriptor
        
        // Gizmo pipeline (position + color)
        let gizmoDescriptor = MTLRenderPipelineDescriptor()
        gizmoDescriptor.vertexFunction = library.makeFunction(name: "gizmo_vertex")
        gizmoDescriptor.fragmentFunction = library.makeFunction(name: "gizmo_fragment")
        gizmoDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        gizmoDescriptor.depthAttachmentPixelFormat = .depth32Float
        gizmoDescriptor.vertexDescriptor = gizmoVertexDescriptor
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            gridPipelineState = try device.makeRenderPipelineState(descriptor: gridDescriptor)
            axisPipelineState = try device.makeRenderPipelineState(descriptor: axisDescriptor)
            gizmoPipelineState = try device.makeRenderPipelineState(descriptor: gizmoDescriptor)
        } catch {
            fatalError("Pipeline creation failed: \(error)")
        }
    }
    
    func setupScene() {
        // Start with an empty scene
        sceneObjects = []
    }
    
    // MARK: - Geometry Creation
    func createPrimitives() {
        createCube()
        createSphere(segments: 32)
        createCylinder(segments: 32)
        createGrid()
        createAxes()
        createAxisGizmo()
    }
    
    func createCube() {
        let vertices: [SIMD3<Float>] = [
            // Front
            [-0.5, -0.5,  0.5], [0.5, -0.5,  0.5], [0.5,  0.5,  0.5], [-0.5,  0.5,  0.5],
            // Back
            [-0.5, -0.5, -0.5], [-0.5,  0.5, -0.5], [0.5,  0.5, -0.5], [0.5, -0.5, -0.5],
            // Left
            [-0.5, -0.5, -0.5], [-0.5, -0.5,  0.5], [-0.5,  0.5,  0.5], [-0.5,  0.5, -0.5],
            // Right
            [0.5, -0.5, -0.5], [0.5,  0.5, -0.5], [0.5,  0.5,  0.5], [0.5, -0.5,  0.5],
            // Top
            [-0.5,  0.5, -0.5], [-0.5,  0.5,  0.5], [0.5,  0.5,  0.5], [0.5,  0.5, -0.5],
            // Bottom
            [-0.5, -0.5, -0.5], [0.5, -0.5, -0.5], [0.5, -0.5,  0.5], [-0.5, -0.5,  0.5]
        ]
        
        let indices: [UInt16] = [
            0, 1, 2, 2, 3, 0,    // Front
            4, 5, 6, 6, 7, 4,     // Back
            8, 9, 10, 10, 11, 8,  // Left
            12, 13, 14, 14, 15, 12, // Right
            16, 17, 18, 18, 19, 16, // Top
            20, 21, 22, 22, 23, 20  // Bottom
        ]
        
        vertexBuffers["cube"] = device.makeBuffer(bytes: vertices,
                                                  length: vertices.count * MemoryLayout<SIMD3<Float>>.stride,
                                                  options: [])
        indexBuffers["cube"] = device.makeBuffer(bytes: indices,
                                                 length: indices.count * MemoryLayout<UInt16>.stride,
                                                 options: [])
    }
    
    func createSphere(segments: Int) {
        var vertices: [SIMD3<Float>] = []
        var indices: [UInt16] = []
        
        // Generate sphere vertices
        for i in 0...segments {
            let v = Float(i) / Float(segments)
            let phi = v * .pi
            
            for j in 0...segments {
                let u = Float(j) / Float(segments)
                let theta = u * .pi * 2
                
                let x = sin(phi) * cos(theta) * 0.5
                let y = cos(phi) * 0.5
                let z = sin(phi) * sin(theta) * 0.5
                
                vertices.append(SIMD3<Float>(x, y, z))
            }
        }
        
        // Generate indices
        for i in 0..<segments {
            for j in 0..<segments {
                let first = i * (segments + 1) + j
                let second = first + segments + 1
                
                indices.append(UInt16(first))
                indices.append(UInt16(second))
                indices.append(UInt16(first + 1))
                
                indices.append(UInt16(second))
                indices.append(UInt16(second + 1))
                indices.append(UInt16(first + 1))
            }
        }
        
        vertexBuffers["sphere"] = device.makeBuffer(bytes: vertices,
                                                    length: vertices.count * MemoryLayout<SIMD3<Float>>.stride,
                                                    options: [])
        indexBuffers["sphere"] = device.makeBuffer(bytes: indices,
                                                   length: indices.count * MemoryLayout<UInt16>.stride,
                                                   options: [])
    }
    
    func createCylinder(segments: Int) {
        var vertices: [SIMD3<Float>] = []
        var indices: [UInt16] = []
        
        // Bottom cap
        vertices.append(SIMD3<Float>(0, -0.5, 0))
        for i in 0..<segments {
            let angle = Float(i) / Float(segments) * .pi * 2
            let x = cos(angle) * 0.5
            let z = sin(angle) * 0.5
            vertices.append(SIMD3<Float>(x, -0.5, z))
        }
        
        // Top cap
        vertices.append(SIMD3<Float>(0, 0.5, 0))
        for i in 0..<segments {
            let angle = Float(i) / Float(segments) * .pi * 2
            let x = cos(angle) * 0.5
            let z = sin(angle) * 0.5
            vertices.append(SIMD3<Float>(x, 0.5, z))
        }
        
        // Sides
        for i in 0..<segments {
            let angle = Float(i) / Float(segments) * .pi * 2
            let x = cos(angle) * 0.5
            let z = sin(angle) * 0.5
            vertices.append(SIMD3<Float>(x, -0.5, z))
            vertices.append(SIMD3<Float>(x, 0.5, z))
        }
        
        // Bottom cap indices
        for i in 1...segments {
            let next = i + 1 > segments ? 1 : i + 1
            indices.append(0)
            indices.append(UInt16(i))
            indices.append(UInt16(next))
        }
        
        // Top cap indices
        let topCenter = UInt16(segments + 1)
        for i in 1...segments {
            let current = topCenter + UInt16(i)
            let next = i + 1 > segments ? topCenter + 1 : topCenter + UInt16(i + 1)
            indices.append(topCenter)
            indices.append(next)
            indices.append(current)
        }
        
        // Side indices
        let sideStart = UInt16(2 * (segments + 1))
        for i in 0..<segments {
            let base = sideStart + UInt16(i * 2)
            indices.append(base)
            indices.append(base + 1)
            indices.append(base + 2)
            
            indices.append(base + 1)
            indices.append(base + 3)
            indices.append(base + 2)
        }
        
        vertexBuffers["cylinder"] = device.makeBuffer(bytes: vertices,
                                                      length: vertices.count * MemoryLayout<SIMD3<Float>>.stride,
                                                      options: [])
        indexBuffers["cylinder"] = device.makeBuffer(bytes: indices,
                                                     length: indices.count * MemoryLayout<UInt16>.stride,
                                                     options: [])
    }
    
    func createGrid() {
        var vertices: [SIMD3<Float>] = []
        let halfSize = gridSize / 2
        let step = gridSize / Float(gridDivisions)
        
        // Horizontal lines
        for i in 0...gridDivisions {
            let z = -halfSize + Float(i) * step
            vertices.append(SIMD3<Float>(-halfSize, 0, z))
            vertices.append(SIMD3<Float>(halfSize, 0, z))
        }
        
        // Vertical lines
        for i in 0...gridDivisions {
            let x = -halfSize + Float(i) * step
            vertices.append(SIMD3<Float>(x, 0, -halfSize))
            vertices.append(SIMD3<Float>(x, 0, halfSize))
        }
        
        vertexBuffers["grid"] = device.makeBuffer(bytes: vertices,
                                                  length: vertices.count * MemoryLayout<SIMD3<Float>>.stride,
                                                  options: [])
    }
    
    func createAxes() {
        let length: Float = 2.0
        let vertices: [SIMD3<Float>] = [
            // X axis (red)
            [0, 0, 0], [length, 0, 0],
            // Y axis (green)
            [0, 0, 0], [0, length, 0],
            // Z axis (blue)
            [0, 0, 0], [0, 0, length]
        ]
        
        vertexBuffers["axes"] = device.makeBuffer(bytes: vertices,
                                                  length: vertices.count * MemoryLayout<SIMD3<Float>>.stride,
                                                  options: [])
    }
    
    // MARK: - Rendering
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }
        
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setDepthStencilState(depthStencilState)
        
        // Calculate matrices
        let aspect = Float(view.drawableSize.width / view.drawableSize.height)
        let projectionMatrix = isOrthographic ?
        float4x4(orthographicLeft: -camera.zoom * aspect, right: camera.zoom * aspect,
                 bottom: -camera.zoom, top: camera.zoom,
                 nearZ: 0.1, farZ: 100) :
        float4x4(perspectiveFov: camera.fov, aspect: aspect, nearZ: 0.1, farZ: 100)
        
        let viewMatrix = camera.viewMatrix
        
        // Draw grid
        var gridMVP = projectionMatrix * viewMatrix
        encoder?.setRenderPipelineState(gridPipelineState)
        encoder?.setVertexBuffer(vertexBuffers["grid"], offset: 0, index: 0)
        encoder?.setVertexBytes(&gridMVP, length: MemoryLayout<float4x4>.stride, index: 1)
        encoder?.drawPrimitives(type: .line, vertexStart: 0, vertexCount: (gridDivisions + 1) * 4)
        
        // Draw axes
        var axisMVP = projectionMatrix * viewMatrix
        encoder?.setRenderPipelineState(axisPipelineState)
        encoder?.setVertexBuffer(vertexBuffers["axes"], offset: 0, index: 0)
        encoder?.setVertexBytes(&axisMVP, length: MemoryLayout<float4x4>.stride, index: 1)
        encoder?.drawPrimitives(type: .line, vertexStart: 0, vertexCount: 6)
        
        // Draw objects
        encoder?.setRenderPipelineState(pipelineState)
        for object in sceneObjects {
            var modelMatrix = object.transformMatrix
            var mvp = projectionMatrix * viewMatrix * modelMatrix
            
            let isSelected = object.id == selectedObjectID
            var color: SIMD4<Float> = isSelected ?
            [1, 0.8, 0, 1] : // Selected - gold
            [0.4, 0.6, 1.0, 1.0] // Default - light blue
            
            encoder?.setVertexBuffer(vertexBuffers[object.type.rawValue], offset: 0, index: 0)
            encoder?.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.stride, index: 1)
            encoder?.setVertexBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 2)
            
            if let indexBuffer = indexBuffers[object.type.rawValue] {
                let indexCount = indexBuffer.length / MemoryLayout<UInt16>.stride
                encoder?.drawIndexedPrimitives(type: .triangle,
                                               indexCount: indexCount,
                                               indexType: .uint16,
                                               indexBuffer: indexBuffer,
                                               indexBufferOffset: 0)
            }
        }
        
        // Draw axis gizmo for selected object
        if let encoder = encoder {
            drawAxisGizmo(encoder: encoder, viewMatrix: viewMatrix, projectionMatrix: projectionMatrix)
        }
        
        encoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
    
    // MARK: - Interaction Methods
    func selectObject(at screenPoint: CGPoint, in view: MTKView) {
        guard let mtkView = mtkView else { return }
        
        // Convert screen point to normalized device coordinates
        let viewportSize = mtkView.drawableSize
        let x = 2.0 * Float(screenPoint.x) / Float(viewportSize.width) - 1.0
        let y = 1.0 - (2.0 * Float(screenPoint.y)) / Float(viewportSize.height)
        
        // Create ray in world space
        let aspect = Float(viewportSize.width / viewportSize.height)
        let projectionMatrix = isOrthographic ?
        float4x4(orthographicLeft: -camera.zoom * aspect, right: camera.zoom * aspect,
                 bottom: -camera.zoom, top: camera.zoom,
                 nearZ: 0.1, farZ: 100) :
        float4x4(perspectiveFov: camera.fov, aspect: aspect, nearZ: 0.1, farZ: 100)
        
        let viewMatrix = camera.viewMatrix
        let inverseViewProjection = (projectionMatrix * viewMatrix).inverse
        
        let nearPoint = inverseViewProjection * SIMD4<Float>(x, y, -1, 1)
        let farPoint = inverseViewProjection * SIMD4<Float>(x, y, 1, 1)
        
        let rayOrigin = nearPoint.xyz / nearPoint.w
        let rayEnd = farPoint.xyz / farPoint.w
        let rayDirection = normalize(rayEnd - rayOrigin)
        
        // Find closest intersected object
        var closestObject: (object: SceneObject, distance: Float)? = nil
        
        for object in sceneObjects {
            let modelMatrix = object.transformMatrix
            let inverseModelMatrix = modelMatrix.inverse
            
            // Transform ray to object's local space
            let localRayOrigin = inverseModelMatrix * SIMD4<Float>(rayOrigin, 1.0)
            let localRayDirection = inverseModelMatrix * SIMD4<Float>(rayDirection, 0.0)
            
            // Simple bounding sphere intersection test
            let boundingSphereRadius: Float = 0.866 // sqrt(3)/2 for unit cube (worst case)
            let sphereCenter = SIMD3<Float>(0, 0, 0)
            
            let oc = sphereCenter - localRayOrigin.xyz
            let tca = dot(oc, localRayDirection.xyz)
            let d2 = dot(oc, oc) - tca * tca
            let radius2 = boundingSphereRadius * boundingSphereRadius
            
            if d2 <= radius2 {
                let thc = sqrt(radius2 - d2)
                let t0 = tca - thc
                let t1 = tca + thc
                
                if t0 > 0 || t1 > 0 {
                    let distance = min(t0 > 0 ? t0 : t1, t1 > 0 ? t1 : t0)
                    if closestObject == nil || distance < closestObject!.distance {
                        closestObject = (object, distance)
                    }
                }
            }
        }
        
        selectedObjectID = closestObject?.object.id
    }
    // MARK: - Axis Visualization
    struct GizmoVertex {
        var position: SIMD3<Float>
        var color: SIMD4<Float>
        
        init(position: SIMD3<Float>, color: SIMD4<Float>) {
            self.position = position
            self.color = color
        }
    }
    
    private func createAxisGizmo() {
        let axisLength: Float = 2.0  // Increased from 1.5 to 2.0
        let arrowSize: Float = 0.3   // Size of arrowheads
        
        let vertices: [GizmoVertex] = [
            // X axis (red) - line
            GizmoVertex(position: [0, 0, 0], color: [1, 0, 0, 1]),
            GizmoVertex(position: [axisLength, 0, 0], color: [1, 0, 0, 1]),
            
            // Y axis (green) - line
            GizmoVertex(position: [0, 0, 0], color: [0, 1, 0, 1]),
            GizmoVertex(position: [0, axisLength, 0], color: [0, 1, 0, 1]),
            
            // Z axis (blue) - line
            GizmoVertex(position: [0, 0, 0], color: [0, 0, 1, 1]),
            GizmoVertex(position: [0, 0, axisLength], color: [0, 0, 1, 1]),
            
            // X axis arrowheads
            GizmoVertex(position: [axisLength, 0, 0], color: [1, 0.5, 0.5, 1]),
            GizmoVertex(position: [axisLength - arrowSize, arrowSize, 0], color: [1, 0.5, 0.5, 1]),
            
            GizmoVertex(position: [axisLength, 0, 0], color: [1, 0.5, 0.5, 1]),
            GizmoVertex(position: [axisLength - arrowSize, -arrowSize, 0], color: [1, 0.5, 0.5, 1]),
            
            GizmoVertex(position: [axisLength, 0, 0], color: [1, 0.5, 0.5, 1]),
            GizmoVertex(position: [axisLength - arrowSize, 0, arrowSize], color: [1, 0.5, 0.5, 1]),
            
            GizmoVertex(position: [axisLength, 0, 0], color: [1, 0.5, 0.5, 1]),
            GizmoVertex(position: [axisLength - arrowSize, 0, -arrowSize], color: [1, 0.5, 0.5, 1]),
            
            // Y axis arrowheads
            GizmoVertex(position: [0, axisLength, 0], color: [0.5, 1, 0.5, 1]),
            GizmoVertex(position: [arrowSize, axisLength - arrowSize, 0], color: [0.5, 1, 0.5, 1]),
            
            GizmoVertex(position: [0, axisLength, 0], color: [0.5, 1, 0.5, 1]),
            GizmoVertex(position: [-arrowSize, axisLength - arrowSize, 0], color: [0.5, 1, 0.5, 1]),
            
            GizmoVertex(position: [0, axisLength, 0], color: [0.5, 1, 0.5, 1]),
            GizmoVertex(position: [0, axisLength - arrowSize, arrowSize], color: [0.5, 1, 0.5, 1]),
            
            GizmoVertex(position: [0, axisLength, 0], color: [0.5, 1, 0.5, 1]),
            GizmoVertex(position: [0, axisLength - arrowSize, -arrowSize], color: [0.5, 1, 0.5, 1]),
            
            // Z axis arrowheads
            GizmoVertex(position: [0, 0, axisLength], color: [0.5, 0.5, 1, 1]),
            GizmoVertex(position: [arrowSize, 0, axisLength - arrowSize], color: [0.5, 0.5, 1, 1]),
            
            GizmoVertex(position: [0, 0, axisLength], color: [0.5, 0.5, 1, 1]),
            GizmoVertex(position: [-arrowSize, 0, axisLength - arrowSize], color: [0.5, 0.5, 1, 1]),
            
            GizmoVertex(position: [0, 0, axisLength], color: [0.5, 0.5, 1, 1]),
            GizmoVertex(position: [0, arrowSize, axisLength - arrowSize], color: [0.5, 0.5, 1, 1]),
            
            GizmoVertex(position: [0, 0, axisLength], color: [0.5, 0.5, 1, 1]),
            GizmoVertex(position: [0, -arrowSize, axisLength - arrowSize], color: [0.5, 0.5, 1, 1])
        ]
        
        vertexBuffers["axisGizmo"] = device.makeBuffer(bytes: vertices,
                                                    length: vertices.count * MemoryLayout<GizmoVertex>.stride,
                                                    options: [])
    }
    
    private func drawAxisGizmo(encoder: MTLRenderCommandEncoder, viewMatrix: float4x4, projectionMatrix: float4x4) {
        guard let selectedID = selectedObjectID,
              let selectedObject = sceneObjects.first(where: { $0.id == selectedID }),
              let axisGizmoBuffer = vertexBuffers["axisGizmo"] else { return }
        
        let gizmoMatrix = float4x4(translation: selectedObject.position)
        var mvp = projectionMatrix * viewMatrix * gizmoMatrix
        
        encoder.setRenderPipelineState(gizmoPipelineState)
        encoder.setVertexBuffer(axisGizmoBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.stride, index: 1)
        
        // Draw thicker lines by drawing multiple slightly offset lines
        func drawThickLine(start: Int, end: Int) {
            encoder.drawPrimitives(type: .line, vertexStart: start, vertexCount: 2)
            // Uncomment these for even thicker lines if needed
            // encoder.drawPrimitives(type: .line, vertexStart: start, vertexCount: 2)
            // encoder.drawPrimitives(type: .line, vertexStart: start, vertexCount: 2)
        }
        
        // Draw main axes
        drawThickLine(start: 0, end: 1)  // X axis
        drawThickLine(start: 2, end: 3)  // Y axis
        drawThickLine(start: 4, end: 5)  // Z axis
        
        // Draw arrowheads
        for i in stride(from: 6, to: 30, by: 2) {
            encoder.drawPrimitives(type: .line, vertexStart: i, vertexCount: 2)
        }
    }
    
    // MARK: - Enhanced Movement
    
    enum MovementAxis {
        case x, y, z, none
    }
    
    func detectMovementAxis(at screenPoint: CGPoint, in view: MTKView) -> MovementAxis {
        guard let selectedID = selectedObjectID,
              let mtkView = mtkView,
              let selectedObject = sceneObjects.first(where: { $0.id == selectedID }) else {
            return .none
        }
        
        let viewportSize = mtkView.drawableSize
        let x = (2.0 * Float(screenPoint.x) / Float(viewportSize.width)) - 1.0
        let y = 1.0 - (2.0 * Float(screenPoint.y) / Float(viewportSize.height))
        
        let aspect = Float(viewportSize.width / viewportSize.height)
        let projectionMatrix = isOrthographic ?
        float4x4(orthographicLeft: -camera.zoom * aspect, right: camera.zoom * aspect,
                 bottom: -camera.zoom, top: camera.zoom,
                 nearZ: 0.1, farZ: 100) :
        float4x4(perspectiveFov: camera.fov, aspect: aspect, nearZ: 0.1, farZ: 100)
        
        let viewMatrix = camera.viewMatrix
        let gizmoMatrix = float4x4(translation: selectedObject.position)
        let mvp = projectionMatrix * viewMatrix * gizmoMatrix
        
        // Transform axis endpoints to screen space
        func projectPoint(_ point: SIMD3<Float>) -> SIMD2<Float> {
            let projected = mvp * SIMD4<Float>(point, 1)
            let normalized = projected.xy / projected.w
            return SIMD2<Float>(normalized.x, normalized.y)
        }
        
        let origin = projectPoint(SIMD3<Float>(0, 0, 0))
        let xEnd = projectPoint(SIMD3<Float>(1.5, 0, 0))
        let yEnd = projectPoint(SIMD3<Float>(0, 1.5, 0))
        let zEnd = projectPoint(SIMD3<Float>(0, 0, 1.5))
        
        // Check distance to each axis in screen space
        let point = SIMD2<Float>(x, y)
        let threshold: Float = 0.05
        
        func distanceToLine(point: SIMD2<Float>, lineStart: SIMD2<Float>, lineEnd: SIMD2<Float>) -> Float {
            let lineVec = lineEnd - lineStart
            let pointVec = point - lineStart
            let lineLength = length(lineVec)
            let lineUnitVec = lineVec / lineLength
            
            let projectedLength = dot(pointVec, lineUnitVec)
            
            if projectedLength < 0 {
                return distance(point, lineStart)
            } else if projectedLength > lineLength {
                return distance(point, lineEnd)
            } else {
                let closestPoint = lineStart + lineUnitVec * projectedLength
                return distance(point, closestPoint)
            }
        }
        
        let xDist = distanceToLine(point: point, lineStart: origin, lineEnd: xEnd)
        let yDist = distanceToLine(point: point, lineStart: origin, lineEnd: yEnd)
        let zDist = distanceToLine(point: point, lineStart: origin, lineEnd: zEnd)
        
        let minDist = min(xDist, yDist, zDist)
        
        if minDist > threshold {
            return .none
        }
        
        if minDist == xDist {
            return .x
        } else if minDist == yDist {
            return .y
        } else {
            return .z
        }
    }
    
    func moveSelectedObject(translation: SIMD3<Float>, along axis: MovementAxis) {
        guard let selectedID = selectedObjectID,
              let index = sceneObjects.firstIndex(where: { $0.id == selectedID }) else { return }
        
        var effectiveTranslation = SIMD3<Float>(0, 0, 0)
        
        switch axis {
        case .x:
            effectiveTranslation = SIMD3<Float>(translation.x, 0, 0)
        case .y:
            effectiveTranslation = SIMD3<Float>(0, translation.y, 0)
        case .z:
            effectiveTranslation = SIMD3<Float>(0, 0, translation.z)
        case .none:
            // Free movement if no axis selected
            effectiveTranslation = translation
        }
        
        sceneObjects[index].position += effectiveTranslation
    }
    
    func moveSelectedObject(translation: SIMD3<Float>) {
        guard let selectedID = selectedObjectID,
              let index = sceneObjects.firstIndex(where: { $0.id == selectedID }) else { return }
        sceneObjects[index].position += translation
    }
    
    func rotateSelectedObject(rotation: SIMD3<Float>) {
        guard let selectedID = selectedObjectID,
              let index = sceneObjects.firstIndex(where: { $0.id == selectedID }) else { return }
        sceneObjects[index].rotation += rotation
    }
    
    // Add to CADRenderer class
    func addObject(_ object: SceneObject) {
        DispatchQueue.main.async {
            self.sceneObjects.append(object)
            self.selectedObjectID = object.id
        }
    }
    
    func toggleProjectionMode() {
        DispatchQueue.main.async {
            self.isOrthographic.toggle()
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view size changes
    }
}

// MARK: - Supporting Types
struct SceneObject {
    let id = UUID()
    let type: ObjectType
    var position: SIMD3<Float>
    var rotation: SIMD3<Float> = [0, 0, 0]
    var scale: SIMD3<Float>
    
    var transformMatrix: float4x4 {
        float4x4(translation: position) *
        float4x4(rotationX: rotation.x) *
        float4x4(rotationY: rotation.y) *
        float4x4(rotationZ: rotation.z) *
        float4x4(scaling: scale)
    }
}

enum ObjectType: String {
    case cube
    case sphere
    case cylinder
}

class Camera {
    var position: SIMD3<Float> = [0, 1, 5]
    var rotation: SIMD2<Float> = [0, 0] // x, y rotations
    var zoom: Float = 5
    var fov: Float = .pi / 3
    
    var viewMatrix: float4x4 {
        float4x4(translation: [0, 0, -zoom]) *
        float4x4(rotationX: rotation.x) *
        float4x4(rotationY: rotation.y) *
        float4x4(translation: [-position.x, -position.y, -position.z])
    }
    
    func rotate(deltaX: Float, deltaY: Float) {
        rotation.x += deltaY * 0.5
        rotation.y += deltaX * 0.5
    }
    
    func pan(deltaX: Float, deltaY: Float) {
        let right = SIMD3<Float>(viewMatrix.columns.0.x, viewMatrix.columns.0.y, viewMatrix.columns.0.z)
        let up = SIMD3<Float>(viewMatrix.columns.1.x, viewMatrix.columns.1.y, viewMatrix.columns.1.z)
        
        position -= right * deltaX * zoom * 0.05
        position += up * deltaY * zoom * 0.05
    }
    
    func zoom(delta: Float) {
        zoom = max(1, min(20, zoom * (1 + delta)))
    }
}
// MARK: - Matrix Extensions
extension float4x4 {
    init(perspectiveFov fovY: Float, aspect: Float, nearZ: Float, farZ: Float) {
        let yScale = 1 / tan(fovY * 0.5)
        let xScale = yScale / aspect
        let zRange = farZ - nearZ
        let zScale = -(farZ + nearZ) / zRange
        let wzScale = -2 * farZ * nearZ / zRange
        
        self.init(columns: (
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, 0, zScale, -1),
            SIMD4<Float>(0, 0, wzScale, 0)
        ))
    }
    
    init(orthographicLeft left: Float, right: Float, bottom: Float, top: Float, nearZ: Float, farZ: Float) {
        let sx = 2 / (right - left)
        let sy = 2 / (top - bottom)
        let sz = -2 / (farZ - nearZ)
        let tx = -(right + left) / (right - left)
        let ty = -(top + bottom) / (top - bottom)
        let tz = -(farZ + nearZ) / (farZ - nearZ)
        
        self.init(columns: (
            SIMD4<Float>(sx, 0, 0, 0),
            SIMD4<Float>(0, sy, 0, 0),
            SIMD4<Float>(0, 0, sz, 0),
            SIMD4<Float>(tx, ty, tz, 1)
        ))
    }
    
    init(translation: SIMD3<Float>) {
        self.init(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        ))
    }
    
    init(scaling: SIMD3<Float>) {
        self.init(diagonal: SIMD4<Float>(scaling.x, scaling.y, scaling.z, 1))
    }
    
    init(rotationX angle: Float) {
        self.init(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, cos(angle), sin(angle), 0),
            SIMD4<Float>(0, -sin(angle), cos(angle), 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
    
    init(rotationY angle: Float) {
        self.init(columns: (
            SIMD4<Float>(cos(angle), 0, -sin(angle), 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(sin(angle), 0, cos(angle), 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
    
    init(rotationZ angle: Float) {
        self.init(columns: (
            SIMD4<Float>(cos(angle), sin(angle), 0, 0),
            SIMD4<Float>(-sin(angle), cos(angle), 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
}

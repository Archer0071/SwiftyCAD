//
//  ContentView.swift
//  Pipes
//
//  Created by Adil Hanif on 6/13/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var rendererState = RendererState()
    @State private var showMovementControls = false
    @State private var xPosition: Float = 0
    @State private var yPosition: Float = 0
    @State private var zPosition: Float = 0
    @State private var xRotation: Float = 0
    @State private var yRotation: Float = 0
    @State private var zRotation: Float = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {             // Toolbar at the top
                HStack {
                    Button(action: { rendererState.addShape(.cube) }) {
                        Image(systemName: "cube")
                            .frame(width: 44, height: 44)
                    }
                    Button(action: { rendererState.addShape(.sphere) }) {
                        Image(systemName: "circle")
                            .frame(width: 44, height: 44)
                    }
                    Button(action: { rendererState.addShape(.cylinder) }) {
                        Image(systemName: "cylinder")
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                    Button(action: { rendererState.toggleProjection() }) {
                        Image(systemName: rendererState.isOrthographic ? "perspective" : "orthographic")
                            .frame(width: 44, height: 44)
                    }
                    Button(action: {
                        showMovementControls.toggle()
                        updatePositionValues()
                    }) {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .frame(width: 44, height: 44)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Metal view takes the rest of the space
                MetalView(rendererState: rendererState)
                    .edgesIgnoringSafeArea(.all)
            }
            
            if showMovementControls {
                movementControls
                    .transition(.move(edge: .bottom))
            }
        }
    }
    
    private var movementControls: some View {
         VStack {
             // Position Controls
             Text("Position").font(.headline)
             HStack {
                 Text("X:")
                 Slider(value: $xPosition, in: -10...10, step: 0.1)
                 Text("\(xPosition, specifier: "%.1f")")
             }
             
             HStack {
                 Text("Y:")
                 Slider(value: $yPosition, in: -10...10, step: 0.1)
                 Text("\(yPosition, specifier: "%.1f")")
             }
             
             HStack {
                 Text("Z:")
                 Slider(value: $zPosition, in: -10...10, step: 0.1)
                 Text("\(zPosition, specifier: "%.1f")")
             }
             
             Divider()
             
             // Rotation Controls
             Text("Rotation").font(.headline)
             HStack {
                 Text("X:")
                 Slider(value: $xRotation, in: -.pi...(.pi), step: 0.01)
                 Text("\(xRotation, specifier: "%.2f")")
             }
             
             HStack {
                 Text("Y:")
                 Slider(value: $yRotation, in: -.pi...(.pi), step: 0.01)
                 Text("\(yRotation, specifier: "%.2f")")
             }
             
             HStack {
                 Text("Z:")
                 Slider(value: $zRotation, in: -.pi...(.pi), step: 0.01)
                 Text("\(zRotation, specifier: "%.2f")")
             }
         }
         .padding()
         .background(Color(.systemBackground))
         .cornerRadius(10)
         .shadow(radius: 5)
         .padding()
         .onChange(of: xPosition) { _ in updateObjectPosition() }
         .onChange(of: yPosition) { _ in updateObjectPosition() }
         .onChange(of: zPosition) { _ in updateObjectPosition() }
         .onChange(of: xRotation) { _ in updateObjectRotation() }
         .onChange(of: yRotation) { _ in updateObjectRotation() }
         .onChange(of: zRotation) { _ in updateObjectRotation() }
     }
     
     private func updatePositionValues() {
         if let selected = rendererState.selectedObject {
             xPosition = selected.position.x
             yPosition = selected.position.y
             zPosition = selected.position.z
         }
     }
     
     private func updateRotationValues() {
         if let selected = rendererState.selectedObject {
             xRotation = selected.rotation.x
             yRotation = selected.rotation.y
             zRotation = selected.rotation.z
         }
     }
     
     private func updateObjectPosition() {
         rendererState.updateSelectedObjectPosition(SIMD3<Float>(xPosition, yPosition, zPosition))
     }
     
     private func updateObjectRotation() {
         rendererState.updateSelectedObjectRotation(SIMD3<Float>(xRotation, yRotation, zRotation))
     }
 }

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

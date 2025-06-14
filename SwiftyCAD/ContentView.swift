//
//  ContentView.swift
//  Pipes
//
//  Created by Adil Hanif on 6/13/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var rendererState = RendererState()
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar at the top
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
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Metal view takes the rest of the space
            MetalView(rendererState: rendererState)
                .edgesIgnoringSafeArea(.all)
        }
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

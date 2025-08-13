//
//  GestureControlProApp.swift
//  GestureControlPro
//
//  Created by AI Assistant on 2025-08-13
//

import SwiftUI
import RealityKit
import ARKit
import Vision
import AVFoundation
import Metal
import MetalPerformanceShaders
import MetalPerformanceShadersGraph
import CoreML
import Network
import OSLog
import HandVector

/// Application principale utilisant SwiftUI et les dernières technologies 2025
@main
struct GestureControlProApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var gestureManager = GestureManager()
    @StateObject private var networkService = NetworkService()
    @StateObject private var performanceManager = PerformanceManager()
    
    private let logger = Logger(subsystem: "com.gesturecontrolpro", category: "App")
    
    init() {
        // Configuration des performances optimales
        setupMetalPerformance()
        setupVisionOptimization()
        configureLogging()
    }
    
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(appState)
                .environmentObject(gestureManager)
                .environmentObject(networkService)
                .environmentObject(performanceManager)
                .onAppear {
                    Task {
                        await initializeServices()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
        
        #if os(visionOS)
        ImmersiveSpace(id: "gestureSpace") {
            GestureImmersiveView()
                .environmentObject(gestureManager)
        }
        .immersionStyle(selection: .constant(.progressive), in: .progressive)
        #endif
        
        Settings {
            SettingsView()

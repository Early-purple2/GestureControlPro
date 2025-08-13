//
//  ContentView.swift
//  GestureControlPro
//
//  Created by AI Assistant on 2025-08-13
//

import SwiftUI
import RealityKit
import Vision
import Metal
import Charts
import HandVector

/// Interface principale avec tracking gestuel en temps réel
struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var gestureManager: GestureManager
    @EnvironmentObject private var networkService: NetworkService
    @EnvironmentObject private var performanceManager: PerformanceManager
    
    @State private var selectedTab: TabSelection = .camera
    @State private var showingSettings = false
    @State private var showingCalibration = false
    @State private var isImmersiveMode = false
    
    var body: some View {
        NavigationSplitView {
            Sidebar()
        } detail: {
            DetailView()
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                StatusIndicators()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingCalibration) {
            CalibrationView()
        }
        .overlay(alignment: .topTrailing) {
            PerformanceHUD()
        }
        .task {
            await startGestureTracking()
        }
    }
    
    // Sidebar, DetailView, StatusIndicators, PerformanceHUD, and startGestureTracking implementations omitted for brevity...
}

enum TabSelection: String, CaseIterable {
    case camera, gestures, network, devices, metrics, debug
    var title: String { ... }
}


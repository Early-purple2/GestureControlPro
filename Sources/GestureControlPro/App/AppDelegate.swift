//
//  AppDelegate.swift
//  GestureControlPro
//
//  Created by AI Assistant on 2025-08-13
//

import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var hostingController: NSHostingController<ContentView>!

    func applicationDidFinishLaunching(_ notification: Notification) {
        hostingController = NSHostingController(rootView: ContentView()
            .environmentObject(AppState())
            .environmentObject(GestureManager())
            .environmentObject(NetworkService())
            .environmentObject(PerformanceManager())
        )

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = hostingController.view
        window.makeKeyAndOrderFront(nil)
    }
}


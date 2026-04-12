import AppKit

// Top-level code in main.swift is implicitly @MainActor in Swift 6.
// This is the entire app entry point — no @NSApplicationMain, no SwiftUI scene.

let appDelegate = AppDelegate()
NSApplication.shared.delegate = appDelegate
NSApplication.shared.run()

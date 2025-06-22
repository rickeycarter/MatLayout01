//
//  FramingMode.swift
//  MatLayout01
//
//  Created by Rickey Carter on 6/21/25.
//


// FramingMode.swift
import Foundation

enum FramingMode: String, CaseIterable, Identifiable {
    case custom = "Custom Mat"
    case standard = "Standard Frame"
    var id: Self { self }
}

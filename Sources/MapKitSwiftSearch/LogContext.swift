//
//  LogContext.swift
//  MapKitSwiftSearch
//
//  Created by Kraig Spear on 12/26/24.
//

import os

/// Defines logging contexts for different areas of the MapKitSwiftSearch framework.
///
/// This enum provides centralized logging configuration that creates categorized
/// loggers for different functional areas. Each context uses a distinct category
/// identifier that includes emoji prefixes for easy visual identification in logs.
///
/// The logging system uses Apple's unified logging (os.Logger) which provides
/// efficient, structured logging that integrates well with Xcode's console and
/// the system's log viewing tools.
enum LogContext: String {
    /// Logging context for location search operations.
    ///
    /// Used to track search requests, results, errors, and performance metrics
    /// for the LocationSearch class and related functionality.
    case locationSearch = "🗺️🔎locationSearch"

    /// Creates a configured logger for this context.
    ///
    /// Each logger uses a consistent subsystem identifier with the context's
    /// category to enable filtering and organization of log messages.
    ///
    /// - Returns: A configured os.Logger instance for this logging context.
    func logger() -> os.Logger {
        os.Logger(subsystem: "com.spareware.MapKitSwiftSearch", category: rawValue)
    }
}

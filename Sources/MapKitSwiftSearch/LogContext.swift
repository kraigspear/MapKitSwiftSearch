//
//  LogContext.swift
//  MapKitSwiftSearch
//
//  Created by Kraig Spear on 12/26/24.
//

import os

enum LogContext: String {
    case locationSearch = "🗺️🔎locationSearch"
    func logger() -> os.Logger {
        os.Logger(subsystem: "com.spareware.MapKitSwiftSearch", category: rawValue)
    }
}

//
//  SelectedLocationView.swift
//  MapKitSwiftSearch
//
//  Created by Kraig Spear on 12/30/24.
//

import MapKit
import SwiftUI

struct SelectedLocationView: View {
    let model: ContentView.Model

    var body: some View {
        @Bindable var model = model
        Map(position: $model.mapCameraPosition) {
            if let placemark = model.selectedPlacemark, let name = placemark.name {
                Marker(
                    name,
                    coordinate: placemark.coordinate
                )
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

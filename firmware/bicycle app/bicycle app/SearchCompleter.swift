//
//  SearchCompleter.swift
//  bicycle app
//
//  Created by Haoge on 2026/3/27.
//

import MapKit

@Observable
final class SearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
    }

    func search(_ fragment: String) {
        if fragment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results = []
            isSearching = false
            completer.cancel()
        } else {
            isSearching = true
            completer.queryFragment = fragment
        }
    }

    func updateRegion(_ coordinate: CLLocationCoordinate2D) {
        completer.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
    }

    func clear() {
        results = []
        isSearching = false
        completer.cancel()
    }

    // MARK: - MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let updated = completer.results
        Task { @MainActor in
            self.results = updated
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
        }
    }
}

//
//  ContentView.swift
//  bicycle app
//
//  Created by Haoge on 2026/3/27.
//

import SwiftUI
import MapKit

enum MapStyleOption: String, CaseIterable {
    case standard
    case satellite
    case hybrid

    var icon: String {
        switch self {
        case .standard: "map"
        case .satellite: "globe.asia.australia"
        case .hybrid: "globe.desk"
        }
    }
}

enum TurnDirection {
    case left, right, straight
}

struct NavigationTurn {
    let coordinate: CLLocationCoordinate2D
    let direction: TurnDirection
    let instruction: String
}

struct MapsView: View {
    var ble: BLEManager

    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.chinese.rawValue

    private var lang: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .chinese
    }

    private var t: L10n { L10n(lang) }

    @State private var locationManager = LocationManager()
    @State private var searchCompleter = SearchCompleter()
    @State private var destination = ""
    @State private var route: MKRoute?
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var isLoading = false
    @State private var statusMessage = ""
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showSteps = false
    @State private var mapStyleOption: MapStyleOption = .standard
    @State private var is3DMode = false
    @State private var isFollowingHeading = false
    @State private var navigationTurns: [NavigationTurn] = []
    @State private var currentNavCommand: String = "0"
    @State private var isNavigating = false
    @State private var showGlassesSheet = false

    private var currentMapStyle: MapStyle {
        let elevation: MapStyle.Elevation = is3DMode ? .realistic : .flat
        switch mapStyleOption {
        case .standard:
            return .standard(elevation: elevation, showsTraffic: true)
        case .satellite:
            return .imagery(elevation: elevation)
        case .hybrid:
            return .hybrid(elevation: elevation, showsTraffic: true)
        }
    }

    var body: some View {
        ZStack {
            mapLayer

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    searchBar
                    mapControlButtons
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()

                VStack(spacing: 12) {
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    if let route {
                        routeInfoCard(route)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdatesIfAuthorized()
        }
        .onChange(of: locationManager.userLocationToken) { _, _ in
            if let location = locationManager.userLocation {
                searchCompleter.updateRegion(location)
                checkNavigationTurns(userLocation: location)
            }
        }
        .sheet(isPresented: $showGlassesSheet) {
            GlassesConnectSheet(ble: ble) {
                showGlassesSheet = false
                beginNavigation()
            }
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            if let destinationCoordinate {
                Marker(t.mapDestinationMarker, systemImage: "flag.fill", coordinate: destinationCoordinate)
                    .tint(.red)
            }

            if let route {
                MapPolyline(route.polyline)
                    .stroke(AppTheme.accent, lineWidth: 5)
            }
        }
        .mapStyle(currentMapStyle)
        .mapControls {
            MapScaleView()
        }
        .ignoresSafeArea(edges: .top)
    }

    private func mapStyleTitle(_ option: MapStyleOption) -> String {
        switch option {
        case .standard: return t.mapStyleStandard
        case .satellite: return t.mapStyleSatellite
        case .hybrid: return t.mapStyleHybrid
        }
    }

    // MARK: - Map Controls

    private var mapControlButtons: some View {
        VStack(spacing: 0) {
            Menu {
                Picker(t.mapStyleMenuTitle, selection: $mapStyleOption) {
                    ForEach(MapStyleOption.allCases, id: \.self) { option in
                        Label(mapStyleTitle(option), systemImage: option.icon)
                            .tag(option)
                    }
                }
            } label: {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 16))
                    .frame(width: 44, height: 44)
            }

            Divider().frame(width: 36)

            Button {
                withAnimation { is3DMode.toggle() }
            } label: {
                Text(is3DMode ? "3D" : "2D")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(is3DMode ? AppTheme.accent : .primary)
                    .frame(width: 44, height: 44)
            }

            Divider().frame(width: 36)

            Button {
                toggleHeading()
            } label: {
                Image(systemName: isFollowingHeading
                      ? "location.north.line.fill"
                      : "location.north.line")
                    .font(.system(size: 16))
                    .foregroundStyle(isFollowingHeading ? AppTheme.accent : .primary)
                    .frame(width: 44, height: 44)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, y: AppTheme.cardShadowY)
    }

    private func toggleHeading() {
        isFollowingHeading.toggle()
        withAnimation {
            if isFollowingHeading {
                cameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
            } else {
                cameraPosition = .userLocation(fallback: .automatic)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(t.mapSearchPlaceholder, text: $destination)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: destination) { _, newValue in
                        searchCompleter.search(newValue)
                    }
                    .onSubmit { navigateToDestination() }

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if !destination.isEmpty {
                    Button {
                        if route != nil { clearRoute() } else {
                            destination = ""
                            searchCompleter.clear()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(10)

            if !searchCompleter.results.isEmpty && route == nil {
                Divider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(
                            Array(searchCompleter.results.prefix(8).enumerated()),
                            id: \.offset
                        ) { _, completion in
                            Button { selectSearchResult(completion) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(completion.title)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        if !completion.subtitle.isEmpty {
                                            Text(completion.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if completion !== searchCompleter.results.prefix(8).last {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, y: AppTheme.cardShadowY)
    }

    // MARK: - Route Info

    private func routeInfoCard(_ route: MKRoute) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDistance(route.distance))
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.text)
                    Text(t.mapETA(formattedTime(route.expectedTravelTime)))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Button {
                    withAnimation { showSteps.toggle() }
                } label: {
                    Label(showSteps ? t.mapStepsHide : t.mapStepsShow,
                          systemImage: showSteps ? "chevron.down" : "list.bullet")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }

            if showSteps {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(route.steps.enumerated()), id: \.offset) { index, step in
                            if !step.instructions.isEmpty {
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(AppTheme.accent, in: Circle())

                                    VStack(alignment: .leading) {
                                        Text(step.instructions)
                                            .font(.callout)
                                            .foregroundStyle(AppTheme.text)
                                        if step.distance > 0 {
                                            Text(formattedDistance(step.distance))
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            if !isNavigating {
                Button {
                    startNavigation()
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                        Text(t.mapStartNavigation)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(ble.glassesState == .connected ? AppTheme.success : AppTheme.warning)
                        .frame(width: 8, height: 8)
                    Text(ble.glassesState == .connected
                         ? t.mapGlassesConnectedLine(name: ble.glassesName ?? t.mapGlassesDefaultName)
                         : t.mapGlassesDisconnected)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    Spacer()
                    if ble.glassesState != .connected {
                        Button(t.mapConnectShort) {
                            showGlassesSheet = true
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(.top, 4)

                Button {
                    stopNavigation()
                } label: {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text(t.mapStopNavigation)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.secondaryText.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(AppTheme.text)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, y: AppTheme.cardShadowY)
    }

    // MARK: - Logic

    private func selectSearchResult(_ completion: MKLocalSearchCompletion) {
        destination = completion.title
        searchCompleter.clear()
        calculateRoute(with: MKLocalSearch.Request(completion: completion))
    }

    private func navigateToDestination() {
        let input = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            statusMessage = t.mapEmptyDestination
            return
        }
        searchCompleter.clear()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = input
        if let userLocation = locationManager.userLocation {
            request.region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        }
        calculateRoute(with: request)
    }

    private func calculateRoute(with searchRequest: MKLocalSearch.Request) {
        isLoading = true
        statusMessage = t.mapSearchingPlace

        Task { @MainActor in
            do {
                let searchResponse = try await MKLocalSearch(request: searchRequest).start()
                guard let mapItem = searchResponse.mapItems.first else {
                    statusMessage = L10n.currentL10n().mapPlaceNotFound
                    isLoading = false
                    return
                }

                destinationCoordinate = mapItem.location.coordinate
                if let name = mapItem.name {
                    destination = name
                }
                statusMessage = L10n.currentL10n().mapPlanningRoute

                let dirRequest = MKDirections.Request()
                dirRequest.source = MKMapItem.forCurrentLocation()
                dirRequest.destination = mapItem
                dirRequest.transportType = .automobile

                let dirResponse = try await MKDirections(request: dirRequest).calculate()

                if let firstRoute = dirResponse.routes.first {
                    route = firstRoute
                    navigationTurns = extractTurns(from: firstRoute)
                    showSteps = false
                    isFollowingHeading = false
                    let rect = firstRoute.polyline.boundingMapRect
                    cameraPosition = .rect(rect.insetBy(
                        dx: -rect.size.width * 0.15,
                        dy: -rect.size.height * 0.15
                    ))
                    statusMessage = ""
                } else {
                    statusMessage = L10n.currentL10n().mapNoRoute
                }
            } catch {
                statusMessage = L10n.currentL10n().mapRouteFailed(error.localizedDescription)
            }
            isLoading = false
        }
    }

    private func startNavigation() {
        if ble.glassesState == .connected {
            beginNavigation()
        } else {
            showGlassesSheet = true
        }
    }

    private func beginNavigation() {
        isNavigating = true
        locationManager.startUpdatesIfAuthorized()
        ble.sendStartSignal()
        withAnimation {
            cameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
            isFollowingHeading = true
            showSteps = false
        }
    }

    private func stopNavigation() {
        isNavigating = false
        currentNavCommand = "0"
        ble.sendNavigationCommand("0")
    }

    private func clearRoute() {
        if isNavigating { stopNavigation() }
        route = nil
        destinationCoordinate = nil
        navigationTurns = []
        statusMessage = ""
        destination = ""
        showSteps = false
        isFollowingHeading = false
        searchCompleter.clear()
        cameraPosition = .userLocation(fallback: .automatic)
    }

    private func formattedDistance(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            return String(format: t.mapDistanceKmFormat, meters / 1000)
        }
        return String(format: t.mapDistanceMetersFormat, meters)
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return t.mapDurationHoursMinutes(hours: hours, minutes: minutes)
        }
        return t.mapDurationMinutes(minutes)
    }

    // MARK: - Navigation Turn Detection

    private func extractTurns(from route: MKRoute) -> [NavigationTurn] {
        var turns: [NavigationTurn] = []
        for step in route.steps {
            let inst = step.instructions
            guard !inst.isEmpty else { continue }
            let dir = parseTurnDirection(inst)
            if dir == .straight { continue }
            let points = step.polyline.points()
            let startPoint = points[0]
            let coord = startPoint.coordinate
            turns.append(NavigationTurn(coordinate: coord, direction: dir, instruction: inst))
        }
        return turns
    }

    private func parseTurnDirection(_ instruction: String) -> TurnDirection {
        let lower = instruction.lowercased()
        let leftKeywords  = ["左转", "向左", "偏左", "turn left", "slight left", "keep left",
                             "bear left", "sharp left"]
        let rightKeywords = ["右转", "向右", "偏右", "turn right", "slight right", "keep right",
                             "bear right", "sharp right"]
        for kw in leftKeywords  where lower.contains(kw) { return .left }
        for kw in rightKeywords where lower.contains(kw) { return .right }
        return .straight
    }

    private func checkNavigationTurns(userLocation: CLLocationCoordinate2D) {
        guard isNavigating, !navigationTurns.isEmpty else {
            if currentNavCommand != "0" {
                currentNavCommand = "0"
                ble.sendNavigationCommand("0")
            }
            return
        }

        // 过差精度会误过滤；城市环境 50m 以内不易达到，放宽以免永远不触发转弯提示。
        let acc = locationManager.userLocationAccuracy
        guard acc > 0, acc <= 120 else { return }

        let userCL = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let approachDistance: CLLocationDistance = 100
        let passedDistance: CLLocationDistance = 35

        // 移除已通过的转弯点
        navigationTurns.removeAll { turn in
            let d = userCL.distance(from: CLLocation(latitude: turn.coordinate.latitude,
                                                     longitude: turn.coordinate.longitude))
            return d < passedDistance
        }

        // 找最近的转弯点
        var nearest: NavigationTurn?
        var nearestDist: CLLocationDistance = .greatestFiniteMagnitude
        for turn in navigationTurns {
            let d = userCL.distance(from: CLLocation(latitude: turn.coordinate.latitude,
                                                     longitude: turn.coordinate.longitude))
            if d < nearestDist {
                nearestDist = d
                nearest = turn
            }
        }

        if let turn = nearest, nearestDist <= approachDistance {
            let cmd = turn.direction == .left ? "L" : "R"
            if cmd != currentNavCommand {
                currentNavCommand = cmd
                ble.sendNavigationCommand(cmd)
            }
        } else {
            if currentNavCommand != "0" {
                currentNavCommand = "0"
                ble.sendNavigationCommand("0")
            }
        }
    }
}

// MARK: - Glasses Connect Sheet

struct GlassesConnectSheet: View {
    var ble: BLEManager
    var onStart: () -> Void

    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.chinese.rawValue
    @Environment(\.dismiss) private var dismiss

    private var lang: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .chinese
    }

    private var t: L10n { L10n(lang) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.accent)
                    Text(t.glassesSheetTitle)
                        .font(.title2.bold())
                    Text(t.glassesSheetSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                if ble.glassesState == .connected {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.success)
                        Text(t.mapGlassesConnectedLine(name: ble.glassesName ?? t.mapGlassesDefaultName))
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.success.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                } else if ble.glassesState == .connecting {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(t.glassesSheetConnecting)
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                } else if ble.glassesScanResults.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(t.glassesSheetScanning)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(ble.glassesScanResults) { device in
                                Button {
                                    ble.connectGlasses(device.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "eyeglasses")
                                            .foregroundStyle(AppTheme.accent)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(device.name)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(AppTheme.text)
                                            Text(t.deviceSignalLabel(rssi: device.rssi))
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }
                                        Spacer()
                                        Text(t.mapConnectShort)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(AppTheme.accent, in: Capsule())
                                            .foregroundStyle(.white)
                                    }
                                    .padding(12)
                                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                                    .shadow(color: AppTheme.cardShadow, radius: 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer()

                VStack(spacing: 10) {
                    if ble.glassesState == .connected {
                        Button {
                            onStart()
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                Text(t.mapStartNavigation)
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        ble.stopGlassesScan()
                        onStart()
                    } label: {
                        Text(t.glassesSheetSkip)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.peopleCancel) {
                        ble.stopGlassesScan()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if ble.glassesState != .connected {
                ble.startGlassesScan()
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    MapsView(ble: BLEManager())
}

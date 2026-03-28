//
//  RelatedPeopleView.swift
//  bicycle app
//

import SwiftUI

struct RelatedPeopleView: View {
    @Bindable var auth: AuthService
    @AppStorage("app_language") private var languageCode = AppLanguage.chinese.rawValue
    @State private var watchList: [WatchListItem] = []
    @State private var selectedPerson: WatchListItem?
    @State private var showAddSheet = false
    @State private var isRefreshing = false
    @State private var detailRefreshTrigger = UUID()

    private var lang: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .chinese
    }

    private var t: L10n { L10n(lang) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if watchList.isEmpty && !isRefreshing && selectedPerson == nil {
                        emptyState
                    } else if !watchList.isEmpty {
                        watchListSection
                    }

                    if let person = selectedPerson {
                        PersonDetailSection(
                            auth: auth,
                            person: person,
                            refreshTrigger: detailRefreshTrigger,
                            languageCode: languageCode
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle(t.peopleNavTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddWatchSheet(auth: auth, languageCode: languageCode) {
                    await loadWatchList()
                }
            }
            .task { await loadWatchList() }
            .refreshable {
                await loadWatchList()
                detailRefreshTrigger = UUID()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.secondaryText.opacity(0.5))
            Text(t.peopleEmptyTitle)
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            Text(t.peopleEmptyHint)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 16)
        .stravaCard()
    }

    private var watchListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t.peopleListSection)
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            ForEach(watchList) { person in
                personRow(person)
            }
        }
    }

    private func personRow(_ person: WatchListItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isSelected(person) ? AppTheme.accent : AppTheme.secondaryText.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(String(person.username.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected(person) ? .white : AppTheme.text)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(person.username)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                if let code = person.inviteCode {
                    Text(t.peopleInviteLabel(code))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            Spacer()

            if isSelected(person) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(14)
        .background(
            isSelected(person)
                ? AppTheme.accent.opacity(0.08)
                : AppTheme.cardBg,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPerson = isSelected(person) ? nil : person
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                Task { await removePerson(person) }
            } label: {
                Label(t.peopleRemove, systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await removePerson(person) }
            } label: {
                Label(t.peopleRemove, systemImage: "trash")
            }
        }
    }

    private func isSelected(_ person: WatchListItem) -> Bool {
        selectedPerson?.id == person.id
    }

    private func loadWatchList() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let newList = await auth.fetchWatchList()
        watchList = newList
        if let selected = selectedPerson, !newList.isEmpty,
           !newList.contains(where: { $0.id == selected.id }) {
            selectedPerson = nil
        }
    }

    private func removePerson(_ person: WatchListItem) async {
        let ok = await auth.removeFromWatchList(person.id)
        if ok {
            if selectedPerson?.id == person.id {
                selectedPerson = nil
            }
            await loadWatchList()
        }
    }
}

// MARK: - Person Detail

struct PersonDetailSection: View {
    @Bindable var auth: AuthService
    let person: WatchListItem
    var refreshTrigger: UUID = UUID()
    let languageCode: String
    @State private var model = RelatedPeopleModel()

    private var taskKey: String { "\(person.id)-\(refreshTrigger)" }

    private var lang: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .chinese
    }

    private var t: L10n { L10n(lang) }

    private var lastUpdatedLabel: String {
        guard let last = model.lastUpdated else { return t.relatedNeverUpdated }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return t.relatedUpdatedAt(formatter.string(from: last))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(t.peopleLiveData(person.username))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.accent)
                }
            }

            dangerCard
            recordsSection
        }
        .task(id: taskKey) {
            await refresh()
        }
    }

    private var dangerCard: some View {
        VStack(spacing: 8) {
            Text(t.peopleDangerTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            Text("\(model.dangerScore)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(dangerColor)
            Text(lastUpdatedLabel)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .stravaCard()
    }

    private var dangerColor: Color {
        if model.dangerScore < 35 { return AppTheme.success }
        if model.dangerScore < 70 { return AppTheme.warning }
        return AppTheme.danger
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t.peopleRecordsTitle)
                .font(.headline)
                .foregroundStyle(AppTheme.text)

            if model.dangerRecords.isEmpty {
                Text(t.peopleRecordsHint)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .stravaCard()
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(model.dangerRecords) { record in
                        dangerRecordRow(record)
                    }
                }
            }
        }
    }

    private func dangerRecordRow(_ record: RemoteDangerRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: sideSymbol(record.angle))
                .font(.title2)
                .foregroundStyle(AppTheme.danger)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(t.peopleRecordLine1(score: record.dangerScore, side: record.sideDescription))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.danger)
                Text(t.peopleRecordLine2(
                    targetId: record.targetId,
                    direction: record.direction,
                    distance: record.distance,
                    speed: record.speed
                ))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Text(record.timeText)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText.opacity(0.8))
        }
        .padding(14)
        .background(AppTheme.cardBg, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.danger.opacity(0.35), lineWidth: 1.5)
        }
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 1)
    }

    private func sideSymbol(_ angle: Int) -> String {
        if angle < -2 { return "arrow.left.circle.fill" }
        if angle > 2 { return "arrow.right.circle.fill" }
        return "arrow.down.circle.fill"
    }

    private func refresh() async {
        guard let token = auth.token else { return }
        await model.refresh(token: token, targetUserId: person.id)
    }
}

// MARK: - Add Watch Sheet

struct AddWatchSheet: View {
    @Bindable var auth: AuthService
    let languageCode: String
    let onAdded: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode = ""
    @State private var successMessage = ""

    private var lang: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .chinese
    }

    private var t: L10n { L10n(lang) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(t.peopleAddHint)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField(t.peopleSheetCodePlaceholder, text: $inviteCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(AppTheme.inputBg, in: RoundedRectangle(cornerRadius: 12))

                if !auth.errorMessage.isEmpty {
                    Text(auth.errorMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !successMessage.isEmpty {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.success)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    submit()
                } label: {
                    Group {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(t.peopleAddButton)
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(auth.isLoading || inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(20)
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle(t.peopleAddNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.peopleCancel) { dismiss() }
                }
            }
        }
    }

    private func submit() {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return }
        auth.errorMessage = ""
        successMessage = ""
        Task {
            let ok = await auth.addToWatchList(code)
            if ok {
                successMessage = t.peopleSheetSuccess
                inviteCode = ""
                await onAdded()
                try? await Task.sleep(for: .seconds(0.8))
                dismiss()
            }
        }
    }
}

// MARK: - Model & API

@Observable
final class RelatedPeopleModel {
    var dangerScore: Int = 0
    var dangerRecords: [RemoteDangerRecord] = []
    var lastUpdated: Date?
    private let api = RelatedPeopleAPI()

    var lastUpdatedText: String {
        guard let lastUpdated else { return "尚未更新" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "更新于 \(formatter.string(from: lastUpdated))"
    }

    func refresh(token: String, targetUserId: String? = nil) async {
        async let danger = api.fetchDanger(token: token, targetUserId: targetUserId)
        async let records = api.fetchDangerRecords(token: token, targetUserId: targetUserId)
        let (dangerValue, recordsValue) = await (danger, records)

        if let dangerValue {
            dangerScore = dangerValue
        }
        if let recordsValue {
            dangerRecords = recordsValue
        }
        lastUpdated = Date()
    }
}

actor RelatedPeopleAPI {
    func fetchDanger(token: String, targetUserId: String? = nil) async -> Int? {
        var urlString = AuthService.baseURL + "/api/radar/danger"
        if let target = targetUserId {
            urlString += "?target=\(target)"
        }
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return json["dangerScore"] as? Int
        } catch {
            return nil
        }
    }

    func fetchDangerRecords(token: String, targetUserId: String? = nil) async -> [RemoteDangerRecord]? {
        var urlString = AuthService.baseURL + "/api/radar/danger-records?limit=30"
        if let target = targetUserId {
            urlString += "&target=\(target)"
        }
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawRecords = json["records"] as? [[String: Any]] else {
                return nil
            }
            return rawRecords.compactMap { RemoteDangerRecord(json: $0) }
        } catch {
            return nil
        }
    }
}

struct RemoteDangerRecord: Identifiable {
    let id: String
    let dangerScore: Int
    let targetId: Int
    let angle: Int
    let distance: Int
    let speed: Int
    let direction: String
    let createdAt: Date?

    nonisolated init?(json: [String: Any]) {
        id = (json["_id"] as? String) ?? UUID().uuidString
        guard let dangerScore = json["dangerScore"] as? Int else { return nil }
        self.dangerScore = dangerScore
        self.targetId = (json["targetId"] as? Int) ?? 0
        self.angle = (json["angle"] as? Int) ?? 0
        self.distance = (json["distance"] as? Int) ?? 0
        self.speed = (json["speed"] as? Int) ?? 0
        self.direction = (json["direction"] as? String) ?? "—"
        if let ts = json["createdAt"] as? String {
            createdAt = ISO8601DateFormatter().date(from: ts)
        } else {
            createdAt = nil
        }
    }

    var sideDescription: String {
        if angle < -2 { return "左侧" }
        if angle > 2 { return "右侧" }
        return "后方"
    }

    var timeText: String {
        guard let createdAt else { return "--:--" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: createdAt)
    }
}

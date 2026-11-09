import SwiftUI

@MainActor
final class CleanerViewModel: ObservableObject {
    @Published private(set) var snapshot = CacheSnapshot(cacheBytes: 0, temporaryBytes: 0, scannedAt: .now)
    @Published private(set) var lastReport: CleanupReport?
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    func refresh() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            snapshot = try await Task.detached(priority: .utility) { try CacheCleaner.scan() }.value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clean() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let report = await Task.detached(priority: .utility) { CacheCleaner.cleanOwnedTemporaryData() }.value
        lastReport = report
        await refreshAfterCleanup()
    }

    private func refreshAfterCleanup() async {
        do { snapshot = try CacheCleaner.scan() }
        catch { errorMessage = error.localizedDescription }
    }
}

struct CleanerDashboardView: View {
    @StateObject private var model = CleanerViewModel()
    @State private var showingConfirmation = false

    private let background = Color(red: 0.025, green: 0.055, blue: 0.035)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    Text("Cleanup")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    storageCard
                    Button { showingConfirmation = true } label: {
                        HStack {
                            Spacer()
                            if model.isBusy { ProgressView().tint(.white) }
                            Text("Delete app temporary data")
                                .font(.system(size: 17, weight: .semibold))
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 21)
                        .background(LinearGradient(colors: [Color(red: 1, green: 0.28, blue: 0.30), Color(red: 0.91, green: 0.16, blue: 0.22)], startPoint: .leading, endPoint: .trailing))
                        .clipShape(Capsule())
                    }
                    .disabled(model.isBusy || model.snapshot.totalBytes == 0)
                    .opacity(model.snapshot.totalBytes == 0 ? 0.55 : 1)

                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            Text("This app's temporary data")
                                .font(.system(size: 19, weight: .semibold))
                            Spacer()
                            Button("Refresh") { Task { await model.refresh() } }
                                .foregroundStyle(.green.opacity(0.9))
                        }
                        dataRow(icon: "shippingbox.fill", title: "Library / Caches", subtitle: "Temporary cached files", value: model.snapshot.cacheBytes.fileSizeLabel)
                        dataRow(icon: "clock.arrow.circlepath", title: "tmp", subtitle: "Temporary working files", value: model.snapshot.temporaryBytes.fileSizeLabel)
                    }
                    .padding(18)
                    .background(.ultraThinMaterial.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    privacyNote
                    if let report = model.lastReport { reportCard(report) }
                    Text("Last scan: \(model.snapshot.scannedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .task { await model.refresh() }
        .confirmationDialog("Clean temporary data?", isPresented: $showingConfirmation, titleVisibility: .visible) {
            Button("Delete temporary files", role: .destructive) { Task { await model.clean() } }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Only CleanerVar's own Caches and tmp folders will be cleared. Documents, settings and sign-ins are not touched.")
        }
        .alert("CleanerVar", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "An unknown error occurred.") }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("CLEANERVAR")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.green.opacity(0.9))
                Text("Storage utility")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Button { Task { await model.refresh() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.green)
                    .frame(width: 58, height: 58)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .disabled(model.isBusy)
        }
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center) {
                Label("ClearVar", systemImage: "sparkles")
                    .font(.system(size: 19, weight: .semibold))
                Spacer()
                Text(model.snapshot.totalBytes.fileSizeLabel)
                    .font(.system(size: 25, weight: .bold, design: .rounded).monospacedDigit())
            }
            Text("Only this app's Library/Caches and tmp files are counted. Personal documents, settings and sign-ins stay untouched.")
                .font(.system(size: 15))
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.88))
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(LinearGradient(colors: [Color(red: 0.95, green: 0.34, blue: 0.32), Color(red: 0.70, green: 0.13, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill").foregroundStyle(.green).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Private by design").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text("iOS apps are isolated from one another. CleanerVar does not bypass that protection or delete another app's data.")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.62)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18))
    }

    private func dataRow(icon: String, title: String, subtitle: String, value: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.green.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.48))
            }
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(.white.opacity(0.85))
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder private func reportCard(_ report: CleanupReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Cleanup complete", systemImage: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.green)
            Text("Freed \(report.removedBytes.fileSizeLabel) across \(report.removedItems) items.")
                .foregroundStyle(.white)
            if !report.failures.isEmpty {
                Text("\(report.failures.count) item(s) could not be removed.")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }
}

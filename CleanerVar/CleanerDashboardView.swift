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
        lastReport = await Task.detached(priority: .utility) {
            CacheCleaner.cleanOwnedTemporaryData()
        }.value
        do {
            snapshot = try CacheCleaner.scan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CleanerDashboardView: View {
    @StateObject private var model = CleanerViewModel()
    @State private var showingConfirmation = false

    private let background = Color(red: 0.025, green: 0.055, blue: 0.035)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        Text("Cleanup")
                            .font(.system(size: min(geometry.size.width * 0.105, 42), weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)

                        storageCard
                        cleanButton
                        ownDataCard
                        allAppsNotice
                        if let report = model.lastReport { reportCard(report) }
                        Text("Last scan: \(model.snapshot.scannedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, horizontalPadding(for: geometry.size.width))
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background.ignoresSafeArea())
        .task { await model.refresh() }
        .confirmationDialog("Clean CleanerVar temporary data?", isPresented: $showingConfirmation, titleVisibility: .visible) {
            Button("Delete CleanerVar cache and tmp", role: .destructive) {
                Task { await model.clean() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Only CleanerVar's own Caches and tmp folders will be cleared. Other apps are not accessed.")
        }
        .alert("CleanerVar", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "An unknown error occurred.")
        }
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        min(max(width * 0.065, 18), 30)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CLEANERVAR")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(.green)
                Text("Storage utility")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer(minLength: 12)
            Button { Task { await model.refresh() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.green)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.08), in: Circle())
                    .contentShape(Circle())
            }
            .disabled(model.isBusy)
            .accessibilityLabel("Refresh cache scan")
        }
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Label("CleanerVar", systemImage: "sparkles")
                    .font(.system(size: 19, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Text(model.snapshot.totalBytes.fileSizeLabel)
                    .font(.system(size: 25, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            Text("Cache and temporary files belonging to CleanerVar only. Other apps' private data is not included.")
                .font(.system(size: 15))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.white.opacity(0.9))
        }
        .foregroundStyle(.white)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(
            colors: [Color(red: 0.95, green: 0.34, blue: 0.32), Color(red: 0.70, green: 0.13, blue: 0.20)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var cleanButton: some View {
        Button { showingConfirmation = true } label: {
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                if model.isBusy { ProgressView().tint(.white) }
                Text("Delete CleanerVar temporary data")
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 21)
            .background(LinearGradient(
                colors: [Color(red: 1, green: 0.28, blue: 0.30), Color(red: 0.78, green: 0.12, blue: 0.18)],
                startPoint: .leading, endPoint: .trailing
            ))
            .clipShape(Capsule())
        }
        .disabled(model.isBusy || model.snapshot.totalBytes == 0)
        .opacity(model.snapshot.totalBytes == 0 ? 0.58 : 1)
    }

    private var ownDataCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("CleanerVar temporary data")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Button("Refresh") { Task { await model.refresh() } }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.green)
            }
            dataRow(icon: "shippingbox.fill", title: "Library / Caches",
                    subtitle: "CleanerVar cached files", value: model.snapshot.cacheBytes.fileSizeLabel)
            Divider().overlay(.white.opacity(0.09))
            dataRow(icon: "clock.arrow.circlepath", title: "tmp",
                    subtitle: "CleanerVar temporary files", value: model.snapshot.temporaryBytes.fileSizeLabel)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var allAppsNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title3)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 6) {
                Text("All-app cache scan is unavailable")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("On a standard, non-jailbroken iPhone, iOS prevents one app from listing or deleting another app's private cache. CleanerVar will not bypass that protection. Use iPhone Settings → General → iPhone Storage to manage each app.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func reportCard(_ report: CleanupReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Cleanup complete", systemImage: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.green)
            Text("Freed \(report.removedBytes.fileSizeLabel) across \(report.removedItems) items.")
                .foregroundStyle(.white)
            if !report.failures.isEmpty {
                Text("\(report.failures.count) item(s) could not be removed.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }
}

import AppKit
import GecitCore
import SwiftUI

/// Menü çubuğundaki kemere tıklayınca açılan panel.
struct MenuPanel: View {
    @EnvironmentObject private var model: AppModel
    @State private var quickAdd = ""
    @State private var addError: String?
    @State private var showFix = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.loaded && !model.status.installed {
                notInstalled
            } else if showFix {
                FixPanel(compact: true)
                Button("Geri") {
                    showFix = false
                    model.resetFix()
                }
                .buttonStyle(.plain)
                .font(Typo.small)
                .foregroundStyle(Palette.muted)
                .disabled(model.busy == .fixing)
            } else {
                header
                groups
                addField
                HStack(spacing: 6) {
                    Button("Açılmıyor mu?") { showFix = true }
                        .buttonStyle(QuietButtonStyle())
                        .frame(maxWidth: .infinity)
                    Button("Pencereyi aç") { AppDelegate.shared?.showMainWindow() }
                        .buttonStyle(QuietButtonStyle())
                        .frame(maxWidth: .infinity)
                }
            }
            Divider().overlay(Palette.line)
            HStack {
                Text(model.launchAtLogin ? "Girişte açılır ✓" : "Girişte açılmaz")
                Spacer()
                Button("Çıkış") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .help("Menü simgesini kapatır. Geçit arka planda çalışmaya devam eder.")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Palette.muted)
        }
        .padding(14)
        .frame(width: 310)
        .foregroundStyle(Palette.fg)
        .font(Typo.body)
        .animation(.easeInOut(duration: 0.2), value: showFix)
        .onAppear { Task { await model.refresh() } }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ArchView(mode: archMode, particles: 16, drawsBackground: true)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typo.display(17))
                Text("\(model.primaryNetwork ?? "Ağ yok") · \(model.status.profile.title) yöntem")
                    .font(Typo.small).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 4)
            Toggle("", isOn: Binding(get: { model.status.enabled }, set: { model.setEnabled($0) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Palette.pass)
                .disabled(model.busy != nil)
        }
    }

    private var groups: some View {
        VStack(spacing: 0) {
            ForEach(SiteGrouping.group(model.status.domains).prefix(5)) { g in
                HStack {
                    Image(systemName: g.symbol).font(.system(size: 11)).foregroundStyle(Palette.muted).frame(width: 16)
                    Text(g.name)
                    Spacer()
                    Text(model.status.isPassing ? "açık" : "engelli")
                        .font(.system(size: 12)).foregroundStyle(model.status.isPassing ? Palette.pass : Palette.muted)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 4)
            }
        }
    }

    private var addField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Hızlı site ekle", text: $quickAdd)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.card))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.line))
                .onSubmit {
                    let text = quickAdd
                    Task {
                        addError = await model.add(text)
                        if addError == nil { quickAdd = "" }
                    }
                }
            if let addError {
                Text(addError).font(.system(size: 11.5)).foregroundStyle(Palette.stop)
            }
        }
    }

    private var notInstalled: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ArchView(mode: .closed, particles: 12, drawsBackground: true).frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kurulum gerekli").font(Typo.display(16))
                    Text("Bir kez kurman yeterli.").font(Typo.small).foregroundStyle(Palette.muted)
                }
            }
            Button("Kurulumu aç") { AppDelegate.shared?.showMainWindow() }
                .buttonStyle(AccentButtonStyle())
        }
    }

    private var title: String {
        if model.busy == .toggling { return model.status.enabled ? "Açılıyor…" : "Kapanıyor…" }
        switch model.status.health {
        case .active: return "Geçit açık"
        case .degraded: return "Toparlanıyor"
        case .off: return "Geçit kapalı"
        case .notInstalled: return "Kurulum gerekli"
        }
    }

    private var archMode: ArchView.Mode {
        switch model.status.health {
        case .active: return .open
        case .degraded: return .warning
        case .off, .notInstalled: return .closed
        }
    }
}

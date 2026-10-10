import SwiftUI

/// Çekirdek kurulu değilse gösterilen ilk ekran.
struct WelcomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 20)
            ArchView(mode: model.busy == .installing ? .open : .closed, particles: 30, drawsBackground: true)
                .frame(width: 168, height: 168)
                .shadow(color: Palette.glow.opacity(model.busy == .installing ? 0.35 : 0), radius: 30)
            Text("Engeller için bir geçit")
                .font(Typo.display(30))
                .padding(.top, 6)
            Text("Geçit, Discord gibi engellenen siteleri ve uygulamaları VPN olmadan açar. Yalnızca listedeki sitelere dokunur; diğer her şey eskisi gibi kalır.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 10) {
                Step(title: "Bir kez kur", text: "Mac şifren yalnızca kurulumda bir kez sorulur.")
                Step(title: "Unut gitsin", text: "Açılışta kendiliğinden başlar, ağ değişince kendini ayarlar.")
                Step(title: "Hız aynı", text: "Trafik başka sunucudan dolaşmaz, doğrudan siteye gider.")
            }
            .frame(maxWidth: 640)
            .padding(.vertical, 8)
            Button(model.busy == .installing ? "Kuruluyor…" : "Geçit'i kur", action: model.install)
                .buttonStyle(AccentButtonStyle(big: true))
                .disabled(model.busy != nil || model.bundledCore == nil)
            Text("Kurulum dosyalarını macOS'un kendi şifre penceresiyle /usr/local/macdpi altına koyar.")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.muted)
            Spacer(minLength: 20)
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.4), value: model.busy)
    }
}

private struct Step: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).fontWeight(.semibold)
            Text(text).font(Typo.small).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.line))
    }
}

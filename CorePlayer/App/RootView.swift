import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        Group {
            if auth.isRestoring {
                SplashView()
            } else if auth.isAuthenticated {
                MainView()
            } else {
                LoginView()
            }
        }
        .background(CoreColors.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: auth.isAuthenticated)
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            CoreColors.background.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("core")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Circle()
                        .fill(CoreColors.accent)
                        .frame(width: 10, height: 10)
                }
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: CoreColors.accent))
            }
        }
    }
}

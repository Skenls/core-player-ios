import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore

    @State private var username = ""
    @State private var password = ""
    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case server
        case username
        case password
    }

    var body: some View {
        ZStack {
            background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    logo
                        .padding(.top, 54)

                    VStack(spacing: 14) {
                        field(
                            title: "СЕРВЕР",
                            icon: "server.rack",
                            text: $auth.serverURLString,
                            keyboard: .URL,
                            isSecure: false
                        )
                        .focused($focused, equals: .server)

                        field(
                            title: "ЛОГИН",
                            icon: "person",
                            text: $username,
                            keyboard: .default,
                            isSecure: false
                        )
                        .focused($focused, equals: .username)

                        field(
                            title: "ПАРОЛЬ",
                            icon: "lock",
                            text: $password,
                            keyboard: .default,
                            isSecure: true
                        )
                        .focused($focused, equals: .password)
                    }

                    if let error = auth.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: 0xFF8A80))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(hex: 0x2A1418))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button(action: submit) {
                        HStack(spacing: 10) {
                            if auth.isLoggingIn {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Text(auth.isLoggingIn ? "Подключение…" : "Войти")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(CoreGradients.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: CoreColors.accent.opacity(0.35), radius: 18, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(auth.isLoggingIn)

                    Text("Адрес сервера можно указать как http://192.168.1.10:3000")
                        .font(.system(size: 12))
                        .foregroundColor(CoreColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 24)
            }
        }
        .onSubmit {
            switch focused {
            case .server:
                focused = .username
            case .username:
                focused = .password
            default:
                submit()
            }
        }
        .onAppear {
            if auth.serverURLString.isEmpty {
                auth.serverURLString = "http://localhost:3000"
            }
        }
    }

    private var background: some View {
        ZStack {
            CoreColors.background
            LinearGradient(
                colors: [
                    CoreColors.accent.opacity(0.22),
                    CoreColors.accent.opacity(0.04),
                    CoreColors.background
                ],
                startPoint: .topTrailing,
                endPoint: .center
            )
            Circle()
                .fill(CoreColors.accent.opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: 150, y: -260)
            Circle()
                .fill(Color(hex: 0x3D5AFE).opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: -160, y: 280)
        }
        .ignoresSafeArea()
    }

    private var logo: some View {
        VStack(spacing: 10) {
            HStack(spacing: 2) {
                Text("core")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Circle()
                    .fill(CoreColors.accent)
                    .frame(width: 10, height: 10)
                    .offset(y: 12)
            }
            Text("ТВОЙ МУЗЫКАЛЬНЫЙ СЕРВЕР")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3)
                .foregroundColor(CoreColors.textSecondary)
        }
    }

    @ViewBuilder
    private func field(
        title: String,
        icon: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        isSecure: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(CoreColors.textSecondary)

            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(CoreColors.textSecondary)
                    .frame(width: 20)

                Group {
                    if isSecure {
                        SecureField("", text: text)
                    } else {
                        TextField("", text: text)
                    }
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(CoreColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(CoreColors.divider, lineWidth: 1)
            )
        }
    }

    private func submit() {
        guard !auth.isLoggingIn else { return }
        focused = nil
        Task {
            await auth.login(
                username: username,
                password: password
            )
        }
    }
}

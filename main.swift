import SwiftUI

@main
struct IPABuilderTestApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)

                Text("IPA Builder Test")
                    .font(.title.bold())

                Text("If you can see this, the test app launched successfully.")
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

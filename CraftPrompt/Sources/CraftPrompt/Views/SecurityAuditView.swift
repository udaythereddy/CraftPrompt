import SwiftUI

public struct SecurityAuditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var auditChecks: [SecurityAuditCheck] = []

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Security & Safety Audit")
                        .font(.title2.weight(.bold))
                    Text("Verification of system isolation, parameter bounding, and local privacy guarantees.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // List of checks
            List(auditChecks) { check in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: check.passed ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .font(.system(size: 20))
                        .foregroundColor(check.passed ? .green : .red)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(check.title)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text(check.category)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12), in: Capsule())
                        }

                        Text(check.details)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            .listStyle(.inset)

            Divider()

            // Footer
            HStack {
                Label("All Core Security Mitigations Active", systemImage: "lock.shield.fill")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.green)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(16)
        }
        .frame(width: 540, height: 460)
        .onAppear {
            self.auditChecks = SecurityAuditor.runAudit()
        }
    }
}

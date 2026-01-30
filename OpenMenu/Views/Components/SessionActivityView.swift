//
//  SessionActivityView.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import SwiftUI

struct SessionActivityView: View {
    let session: Session
    let statusType: SessionStatus.SessionActivityStatus

    var body: some View {
        HStack(spacing: 12) {
            if statusType == .busy {
                ProgressView()
                    .scaleEffect(0.6)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            } else {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            }

            Text(session.displayName)
                .font(.system(size: 12))
                .foregroundStyle(statusType == .busy ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if statusType == .busy {
                Text("Generating code")
                    .font(.system(size: 9))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.15))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(statusType == .busy ? Color.blue.opacity(0.08) : Color.primary.opacity(0.05))
        )
        .accessibilityLabel("\(session.displayName) - \(statusType == .busy ? "generating code" : "completed")")
    }
}

struct WorkingSessionsHeader: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
                .scaleEffect(count > 0 ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: count > 0)

            Text(count == 1 ? "Agent Working" : "Agents Working")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
            }
        }
    }
}

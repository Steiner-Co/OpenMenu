//
//  ActionButton.swift
//  OpenMenu
//
//  Created by Arunava Karmakar on 29/01/26.
//

import SwiftUI

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 20)
                
                Text(label)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ActionButton(icon: "safari", label: "Open Portal") {
            print("Open Portal tapped")
        }
        ActionButton(icon: "doc.on.clipboard", label: "Copy Session ID") {
            print("Copy Session ID tapped")
        }
        ActionButton(icon: "arrow.clockwise", label: "Restart Server") {
            print("Restart Server tapped")
        }
    }
    .padding()
    .background(.ultraThinMaterial)
}

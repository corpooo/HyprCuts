//
//  SequenceNotificationView.swift
//  HyprCuts
//
//  Created by Andrei Corpodeanu on 23.04.2025.
//

import SwiftUI

// MARK: - Notification View Definition
struct SequenceNotificationView: View {
  let sequencePath: [String]
  let masterKeyString: String

  private let keySize: CGFloat = 40
  private let keyCornerRadius: CGFloat = 8
  private let keySpacing: CGFloat = 8
  private let keyBackgroundColor = Color.black.opacity(0.9)
  private let keyForegroundColor = Color.white
  private let keyFont = Font.system(size: 20, weight: .medium, design: .monospaced)

  private let capsuleBackgroundColor = Color.black.opacity(0.6)

  var body: some View {
    HStack(spacing: keySpacing) {
      let displayMasterKey = KeyMapping.getDisplayString(for: masterKeyString)
      let displaySequence =
        [displayMasterKey] + sequencePath.map { KeyMapping.getDisplayString(for: $0) }

      ForEach(displaySequence, id: \.self) { displayKeyString in
        // Use ZStack for better control over background shape and text placement
        ZStack {
          // Explicit square background
          RoundedRectangle(cornerRadius: keyCornerRadius)
            .fill(keyBackgroundColor)
            .frame(width: keySize, height: keySize)

          // Text centered on top
          Text(displayKeyString)
            .font(keyFont)
            .foregroundColor(keyForegroundColor)
            .lineLimit(1)  // Prevent wrapping
            .minimumScaleFactor(0.5)  // Allow text to shrink if needed
            .padding(2)  // Small internal padding if text shrinks
        }
        // Ensure ZStack itself doesn't expand beyond the frame
        .frame(width: keySize, height: keySize)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 10)
    .background(
      Capsule().fill(capsuleBackgroundColor)
        .background(.ultraThinMaterial.opacity(0.8))
    )
    .clipShape(Capsule())
    // Remove the shadow from the outer container
    // .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    .fixedSize()
  }
}

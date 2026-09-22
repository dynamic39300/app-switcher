import SwiftUI
import AppSwitcherCore

/// 键盘形状覆盖层视图（SwiftUI）。
struct OverlayView: View {
    let keyMap: [Key: Candidate]

    private static let rows: [[String]] = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"],
    ]

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 10
            let keyW = (geo.size.width - gap * 9) / 10
            let keyH = (geo.size.height - gap * 2) / 3
            let keySize = max(24, min(keyW, keyH))

            VStack(spacing: gap) {
                ForEach(Self.rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(row, id: \.self) { label in
                            keycap(label, size: keySize)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(14)
        .background(Color.black.opacity(0.9))
    }

    private func keycap(_ label: String, size: CGFloat) -> some View {
        let candidate = keyMap[Key(label, letter: true)]
        return VStack(spacing: 2) {
            if let c = candidate {
                Text(truncate(c.displayName, 9))
                    .font(.system(size: size * 0.15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if !c.title.isEmpty {
                    Text(truncate(c.title, 12))
                        .font(.system(size: size * 0.10))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Text(label)
                .font(.system(size: size * 0.22, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: size * 0.16)
                .fill(candidate != nil ? Color.accentColor : Color.white.opacity(0.12))
        )
    }

    private func truncate(_ s: String, _ n: Int) -> String {
        s.count > n ? String(s.prefix(n)) + "…" : s
    }
}

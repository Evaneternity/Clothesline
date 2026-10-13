import SwiftUI

struct PeggedView: View {
    let item: Pegged
    @ObservedObject var line: Line
    @State private var swing: Double = 0
    @State private var arrived = false
    @State private var hovering = false
    private var dragging: Bool { line.draggingID == item.id }
    private var pressed: Bool { line.pressedID == item.id }

    var body: some View {
        VStack(spacing: -12) {
            Clothespin().zIndex(1)
            card
        }
        .rotationEffect(.degrees(swing + item.tilt), anchor: .top)
        .offset(y: arrived ? 0 : -46)
        .opacity(arrived ? 1 : 0)
        .onAppear {
            swing = 16
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { arrived = true }
            withAnimation(.interpolatingSpring(stiffness: 46, damping: 2.6)) { swing = 0 }
        }
        .onChange(of: line.gust) { _, _ in
            withAnimation(.easeOut(duration: 0.4)) { swing = 2.5 }
            withAnimation(.interpolatingSpring(stiffness: 38, damping: 2.4).delay(0.35)) { swing = 0 }
        }
    }

    private var card: some View {
        VStack(spacing: 4) {
            Image(nsImage: item.thumb)
                .resizable().interpolation(.high)
                .scaledToFit()
                .frame(width: Layout.cardWidth - 24, height: Layout.photoMaxHeight - 14)
                .overlay {
                    if item.isRecording {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 26, height: 26)
                            .glassFrame(circle: true)
                            .allowsHitTesting(false)
                    }
                }
            Text(item.url.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: Layout.cardWidth - 24)
                .help(item.url.lastPathComponent)
        }
        .padding(6)
        .frame(width: Layout.cardWidth - 8)
        .glassFrame(cornerRadius: 15)
        .shadow(color: .black.opacity(hovering ? 0.26 : 0.18), radius: hovering ? 14 : 10, y: hovering ? 8 : 5)
        .scaleEffect(pressed ? 0.95 : (hovering ? 1.035 : 1), anchor: .top)
        .animation(.spring(response: 0.30, dampingFraction: 0.65), value: hovering)
        .opacity(dragging ? 0.45 : 1)
        .overlay(alignment: .topLeading) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 20, height: 20)
                .glassFrame(circle: true)
                .padding(3)
                .opacity(hovering && !dragging ? 1 : 0)
                .allowsHitTesting(false)
        }
        .overlay(GrabArea(item: item, line: line))
        .overlay(alignment: .bottom) {
            if line.copiedID == item.id {
                Label("已复制文件", systemImage: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .glassFrame(capsule: true)
                    .offset(y: 18)
            }
        }
        .onHover { hovering = $0 }
        .background(GeometryReader { g in
            Color.clear.preference(key: HitRectsKey.self,
                value: [item.id: g.frame(in: .global)])
        })
    }
}

extension View {
    func glassFrame(cornerRadius: CGFloat = 0, circle: Bool = false, capsule: Bool = false) -> some View {
        let shape: AnyShape = circle ? AnyShape(Circle())
            : capsule ? AnyShape(Capsule())
            : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        return background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.12)],
                                                  startPoint: .top, endPoint: .bottom), lineWidth: 0.75))
            .overlay(shape.stroke(Color.black.opacity(0.10), lineWidth: 0.5).padding(-0.5))
    }
}

struct Clothespin: View {
    private let metal = LinearGradient(stops: [
        .init(color: Color(white: 0.70), location: 0),
        .init(color: Color(white: 0.93), location: 0.35),
        .init(color: Color(white: 0.82), location: 0.65),
        .init(color: Color(white: 0.62), location: 1)
    ], startPoint: .leading, endPoint: .trailing)
    var body: some View {
        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
            .fill(metal).frame(width: 9, height: 26)
            .overlay(RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .stroke(LinearGradient(colors: [Color.white.opacity(0.9), Color.black.opacity(0.18)],
                                       startPoint: .top, endPoint: .bottom), lineWidth: 0.6))
            .overlay(alignment: .top) {
                Capsule().fill(Color.black.opacity(0.32))
                    .frame(width: 5, height: 1.4).padding(.top, 8.5)
            }
            .shadow(color: .black.opacity(0.30), radius: 2, y: 1.5)
            .allowsHitTesting(false)
    }
}

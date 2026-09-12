import SwiftUI

/// 黑胶唱片旋转动画组件
struct VinylRecordView: View {
    let coverImagePath: String?
    let isPlaying: Bool
    let size: CGFloat

    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            // 黑胶唱片底色
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.black, Color(white: 0.15),
                            Color(white: 0.05), Color(white: 0.2),
                            Color.black
                        ]),
                        center: .center
                    )
                )
                .frame(width: size, height: size)

            // 唱片刻纹
            ForEach(0..<8) { i in
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                    .frame(width: size * CGFloat(0.85 - Double(i) * 0.08), height: size * CGFloat(0.85 - Double(i) * 0.08))
            }

            // 专辑封面
            if let path = coverImagePath, let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size * 0.45, height: size * 0.45)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            } else {
                // 默认图标
                Circle()
                    .fill(Color(hex: "6C5CE7").opacity(0.3))
                    .frame(width: size * 0.45, height: size * 0.45)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.18))
                            .foregroundColor(.white)
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            }

            // 中心圆孔
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.06, height: size * 0.06)
        }
        .rotationEffect(.degrees(rotationAngle))
        // 只由下面的 onChange 驱动旋转。
        // 之前这里还挂了一个 .animation(value: isPlaying)，和 onChange 里的
        // withAnimation 双重驱动同一属性，动画会互相打断、看起来一顿一顿的。
        .onChange(of: isPlaying) { newValue in
            if newValue {
                // 从当前角度继续转（模拟唱片机）
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    rotationAngle = rotationAngle.truncatingRemainder(dividingBy: 360) + 360
                }
            } else {
                withAnimation(.easeOut(duration: 0.35)) {
                    rotationAngle = rotationAngle.truncatingRemainder(dividingBy: 360)
                }
            }
        }
        // 阴影
        .shadow(color: .black.opacity(0.3), radius: 15, x: 5, y: 5)
    }
}

#Preview {
    VinylRecordView(coverImagePath: nil, isPlaying: true, size: 300)
        .padding()
        .background(Color(hex: "1A1A2E"))
}

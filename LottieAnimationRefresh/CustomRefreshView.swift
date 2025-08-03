//
//  View+ScrollViewRefresher.swift
//  LottieAnimationRefresh
//
//  Created by name on 03/08/2025.
//
import SwiftUI
import Lottie

// MARK: - View Extension for Lottie Pull-to-Refresh
extension View {
  @ViewBuilder
  func scrollViewRefresher(
    showIndicator: Bool = true,
    lottieFileName: String,
    triggerDistance: CGFloat = 100,
    onRefresh: @escaping () async -> ()
  ) -> some View {
    CustomRefreshView(
      showIndicator: showIndicator,
      lottieFileName: lottieFileName,
      triggerDistance: triggerDistance,
      content: { self },
      onRefresh: onRefresh
    )
  }
}

// MARK: - Custom View Builder (Internal Implementation)
private struct CustomRefreshView<Content: View>: View {
  var content: Content
  var showIndicator: Bool
  var lottieFileName: String
  var triggerDistance: CGFloat
  var onRefresh: () async -> ()

  init(
    showIndicator: Bool = true,
    lottieFileName: String,
    triggerDistance: CGFloat = 100,
    @ViewBuilder content: @escaping () -> Content,
    onRefresh: @escaping () async -> ()
  ) {
    self.showIndicator = showIndicator
    self.lottieFileName = lottieFileName
    self.triggerDistance = triggerDistance
    self.content = content()
    self.onRefresh = onRefresh
  }

  @StateObject private var scrollDelegate: ScrollViewModel = .init()
  
  var body: some View {
    ScrollView(.vertical, showsIndicators: showIndicator) {
      VStack(spacing: 0) {
        Rectangle()
          .fill(.clear)
          .scaleEffect(scrollDelegate.isEligible ? 1 : 0.001)
          .animation(.easeInOut(duration: 0.2), value: scrollDelegate.isEligible)
          .overlay(content: {
            ResizableLottieView(
              fileName: lottieFileName,
              isPlaying: $scrollDelegate.isRefreshing,
              progressPoint: $scrollDelegate.progress
            )
          })
          .frame(height: max(0, triggerDistance * scrollDelegate.progress))
          .opacity(scrollDelegate.progress)
          .offset(y: scrollDelegate.isEligible ?
                   -(scrollDelegate.contentOffset < 0 ? 0 : scrollDelegate.contentOffset) :
                   -(scrollDelegate.scrollOffset < 0 ? 0 : scrollDelegate.scrollOffset))
        
        content
      }
      .offset(coordinateSpace: "SCROLL") { offset in
        // MARK: Storing Content Offset
        scrollDelegate.contentOffset = offset
        
        // MARK: Stop the progress when it's eligible for refresh
        if !scrollDelegate.isEligible {
          var progress = offset / triggerDistance
          progress = max(0, min(1, progress))
          scrollDelegate.scrollOffset = offset
          scrollDelegate.progress = progress
        }
        
        if scrollDelegate.isEligible && !scrollDelegate.isRefreshing {
          scrollDelegate.isRefreshing = true
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
      }
    }
    .coordinateSpace(name: "SCROLL")
    .onAppear { scrollDelegate.addGesture(triggerDistance: triggerDistance) }
    .onDisappear(perform: scrollDelegate.removeGesture)
    .onChange(of: scrollDelegate.isRefreshing) { newValue in
      if newValue {
        Task {
          await onRefresh()
          // MARK: After refresh done, reset properties
          withAnimation(.easeInOut(duration: 0.25)) {
            scrollDelegate.progress = 0
            scrollDelegate.isEligible = false
            scrollDelegate.isRefreshing = false
            scrollDelegate.scrollOffset = 0
          }
        }
      }
    }
  }
}

// MARK: - Scroll View Model for Gesture Handling
private class ScrollViewModel: NSObject, ObservableObject, UIGestureRecognizerDelegate {
  // MARK: Properties
  @Published var isEligible: Bool = false
  @Published var isRefreshing: Bool = false
  @Published var scrollOffset: CGFloat = 0
  @Published var contentOffset: CGFloat = 0
  @Published var progress: CGFloat = 0
  
  private var triggerDistance: CGFloat = 0
    
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    return true
  }
  
  // MARK: Add Gesture to the Top View
  func addGesture(triggerDistance: CGFloat) {
    self.triggerDistance = triggerDistance
    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(onGestureChange(gesture:)))
    panGesture.delegate = self
    rootController().view.addGestureRecognizer(panGesture)
  }
  
  // MARK: Remove gesture recognizers when leaving the view
  func removeGesture() {
    rootController().view.gestureRecognizers?.removeAll()
  }
  
  // MARK: Finding Root Controller
  private func rootController() -> UIViewController {
    guard let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
      return UIViewController()
    }
    
    guard let root = screen.windows.first?.rootViewController else {
      return UIViewController()
    }
    
    return root
  }
  
  @objc
  private func onGestureChange(gesture: UIPanGestureRecognizer) {
    if gesture.state == .cancelled || gesture.state == .ended {
      if !isRefreshing {
        isEligible = scrollOffset > triggerDistance
      }
    }
  }
}

// MARK: - Offset Modifier
private extension View {
  @ViewBuilder
  func offset(coordinateSpace: String, offset: @escaping (CGFloat) -> ()) -> some View {
    self.overlay {
      GeometryReader { proxy in
        let minY = proxy.frame(in: .named(coordinateSpace)).minY

        Color.clear
          .preference(key: OffsetKey.self, value: minY)
          .onPreferenceChange(OffsetKey.self) { value in
            offset(value)
          }
      }
    }
  }
}

// MARK: - Offset Preference Key
private struct OffsetKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

// MARK: - Custom Resizable Lottie View
private struct ResizableLottieView: UIViewRepresentable {
  var fileName: String
  @Binding var isPlaying: Bool
  @Binding var progressPoint: CGFloat

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = .clear
    addLottieView(to: view)
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    for subview in uiView.subviews {
      if subview.tag == 1009, let lottieView = subview as? LottieAnimationView {
        if isPlaying {
          lottieView.play()
        } else {
          lottieView.currentProgress = AnimationProgressTime(progressPoint / 2)
        }
      }
    }
  }

  private func addLottieView(to containerView: UIView) {
    let lottieView = LottieAnimationView(name: fileName, bundle: .main)
    lottieView.backgroundColor = .clear
    lottieView.loopMode = .loop
    lottieView.animationSpeed = 1.0
    lottieView.tag = 1009
    lottieView.translatesAutoresizingMaskIntoConstraints = false

    containerView.addSubview(lottieView)
    
    NSLayoutConstraint.activate([
      lottieView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
      lottieView.heightAnchor.constraint(equalTo: containerView.heightAnchor)
    ])
  }
}

// MARK: - Usage Example
#Preview {
  VStack {
    Text("Pull down to refresh!")
      .font(.title)
      .padding()
    
    ForEach(0..<20, id: \.self) { index in
      HStack {
        Text("Item \(index + 1)")
        Spacer()
        Image(systemName: "star.fill")
          .foregroundColor(.yellow)
      }
      .padding()
      .background(Color.gray.opacity(0.1))
      .cornerRadius(8)
    }
  }
  .padding()
  .scrollViewRefresher(
    showIndicator: false,
    lottieFileName: "LoadingBar",
    triggerDistance: 120
  ) {
    // Simulate network call
    try? await Task.sleep(nanoseconds: 2_000_000_000)
  }
}

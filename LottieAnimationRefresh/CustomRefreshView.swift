//
//  CustomRefreshView.swift
//  LottieAnimationRefresh
//
//  Created by name on 03/08/2025.
//
import SwiftUI
import Lottie

// MARK: - Custom View Builder
struct CustomRefreshView<Content: View>: View {
  var content: Content
  var showIndicator: Bool
  var lottieFileName: String
  var triggerDistance: CGFloat

  // MARK: - Async call back
  var onRefresh: () async -> ()

  init(showIndicator: Bool = true, lottieFileName: String,triggerDistance: CGFloat = 100, @ViewBuilder content: @escaping () -> Content, onRefresh: @escaping () async -> ()) {
    self.showIndicator = showIndicator
    self.lottieFileName = lottieFileName
    self.triggerDistance = triggerDistance
    self.content = content()
    self.onRefresh = onRefresh
  }

  @StateObject var scrollDelegate: ScrollViewModel = .init()
  
  var body: some View {
    
    ScrollView(.vertical, showsIndicators: showIndicator) {
      VStack(spacing: 0){
        Rectangle()
          .fill(.clear)
          .scaleEffect(scrollDelegate.isEligible ? 1 : 0.001)
          .animation(.easeInOut(duration: 0.2), value: scrollDelegate.isEligible)
          .overlay(content: {
            ResizableLottieView(fileName: lottieFileName, isPlaying: $scrollDelegate.isRefreshing, progressPoint: $scrollDelegate.progress)
          })
          .frame(height: max(0, triggerDistance * scrollDelegate.progress))
          .opacity(scrollDelegate.progress)
          .offset(y: scrollDelegate.isEligible ? -(scrollDelegate.contentOffset < 0 ? 0 : scrollDelegate.contentOffset) : -(scrollDelegate.scrollOffset < 0 ? 0 : scrollDelegate.scrollOffset) )
        
        content
      }
      .offset(coordinateSpace: "SCROLL") { offset in
        // MARK: Storing Content Offset
        scrollDelegate.contentOffset = offset
        
        // MARK: Stop the progress when it's Eligible for refresh
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
    .onAppear{scrollDelegate.addGesture(triggerDistance: triggerDistance)}
    .onDisappear(perform: scrollDelegate.removeGesture)
    .onChange(of: scrollDelegate.isRefreshing) { newValue in
      if newValue {
        Task {
          await onRefresh()
          // MARK: After refresh done resetting properties
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

#Preview {
  CustomRefreshView(showIndicator: false, lottieFileName: "LoadingBar") {
    Rectangle()
      .fill(.red)
      .frame(height: 200)
  } onRefresh: {
    try? await Task.sleep(nanoseconds: 2_000_000_000)
  }

}


// MARK: For Simultanous Pan Gesture
class ScrollViewModel: NSObject, ObservableObject, UIGestureRecognizerDelegate{
  // MARK: Properties
  @Published var isEligible: Bool = false
  @Published var isRefreshing: Bool = false
  // MARK: Offset And Progress
  @Published var scrollOffset: CGFloat = 0
  @Published var contentOffset: CGFloat = 0
  @Published var progress: CGFloat = 0
  
  private var triggerDistance: CGFloat = 0
    
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      return true
  }
  
  // MARK: Add Gesture the the Top View
  func addGesture(triggerDistance: CGFloat) {
    self.triggerDistance = triggerDistance
    let pinGesture = UIPanGestureRecognizer(target: self, action: #selector(onGestureChange(gesture:)))
    pinGesture.delegate = self
    rootController().view.addGestureRecognizer(pinGesture)
  }
  
  // MARK: Remove gestureRecognizers when Leaving the View
  func removeGesture() {
    rootController().view.gestureRecognizers?.removeAll()
  }
  
  // MARK: Finding Root Controller -> get the VC from the rootViewContrller
  func rootController() -> UIViewController {
    guard let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return .init() }
    
    guard let root = screen.windows.first?.rootViewController else { return .init() }
    
    return root
  }
  
  @objc
  func onGestureChange(gesture: UIPanGestureRecognizer) {
    if gesture.state == .cancelled || gesture.state == .ended {
      print("User refreshed touch")
      // MARK: Your max duration goes here
      if !isRefreshing {
        if scrollOffset > triggerDistance {
          isEligible = true
        } else {
          isEligible = false
        }
      }
    }
  }
  
}

// MARK: Offset Modifire -> track a view's vertical scroll offset (Y-position) within a named coordinateSpace
extension View {
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

// MARK: Offset Prefernce key
struct OffsetKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

// MARK: Custom Resizable lottie view
struct ResizableLottieView: UIViewRepresentable {
  var fileName: String
  @Binding var isPlaying: Bool
  @Binding var progressPoint: CGFloat

  // MARK: Make LottieView
  func makeUIView(context: Context) -> some UIView {
    let view = UIView()
    view.backgroundColor = .clear
    addLottieView(view: view)
    return view
  }

  // MARK: - Update animation based on scroll progress or play state
  func updateUIView(_ uiView: UIViewType, context: Context) {
    for view in uiView.subviews {
      if view.tag == 1009, let lottieView = view as? LottieAnimationView {
        if isPlaying {
          lottieView.play()
        } else {
          lottieView.currentProgress = AnimationProgressTime(progressPoint/2)
        }
      }
    }
  }

  // MARK: Add Lottie View
  func addLottieView(view to: UIView) {
    let lottieView = LottieAnimationView(name: fileName, bundle: .main)
    lottieView.backgroundColor = .clear
    lottieView.loopMode = .loop
    lottieView.animationSpeed = 1.0
    // MARK: For finding it in subview and used for animation
    lottieView.tag = 1009
    lottieView.translatesAutoresizingMaskIntoConstraints = false

    let constraints = [
      lottieView.widthAnchor.constraint(equalTo: to.widthAnchor),
      lottieView.heightAnchor.constraint(equalTo: to.heightAnchor),
    ]
    to.addSubview(lottieView)
    to.addConstraints(constraints)
  }
}

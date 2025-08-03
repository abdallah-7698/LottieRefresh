//
//  NativeSwiftUILottie.swift
//  LottieAnimationRefresh
//
//  Created by name on 03/08/2025.
//
import SwiftUI
import Lottie

struct NativeSwiftUILottie: View {
  var body: some View {
    LottieView(animation: .named("LoadingBar"))
    // we can replace .play with .paused at a cirtain frame or .paused
    // on the loop we can play once or loop
    //      .playbackMode(.playing(.toProgress(1, loopMode: .playOnce)))
    
  }
}

#Preview {
  NativeSwiftUILottie()
}

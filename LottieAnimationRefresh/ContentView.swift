//
//  ContentView.swift
//  LottieAnimationRefresh
//
//  Created by name on 03/08/2025.
//

import SwiftUI
import Lottie

struct ContentView: View {
    var body: some View {
      CustomRefreshView(showIndicator: false, lottieFileName: "LoadingBar") {
        Rectangle()
          .fill(.red)
          .frame(height: 200)
      } onRefresh: {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
      }
    }
}

#Preview {
    ContentView()
}

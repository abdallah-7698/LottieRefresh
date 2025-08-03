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
}

#Preview {
    ContentView()
}

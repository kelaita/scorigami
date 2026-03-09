//
//  ContentView.swift
//  Scorigami
//
//  Created by Paul Kelaita on 10/19/22.
//

import SwiftUI
import UIKit

struct ContentView: View {
  
  @StateObject var viewModel: ScorigamiViewModel  = ScorigamiViewModel()
  
  var body: some View {
    if !viewModel.isNetworkAvailable() {
      // if no network, put up a screen with exit as the only option;
      // no else needed since we're exiting here
      //
      NetworkFailureExitView()
    }
    ZStack {
      Color.black.ignoresSafeArea()
      VStack(spacing: 0) {
        NavOptions().environmentObject(viewModel)
        OverallView()
          .transition(.scale)
          .environmentObject(viewModel)
        Spacer()
        UIOptions().environmentObject(viewModel)
      }
    }.navigationBarTitleDisplayMode(.inline)
  }
}

struct NavOptions: View {
  @EnvironmentObject var viewModel: ScorigamiViewModel
  var body: some View {
    HStack(spacing: 8) {
      Image("scorigami_title")
        .resizable()
        .scaledToFit()
        .frame(height: 42)
      Spacer(minLength: 0)
      NavigationLink(destination: AboutView()) {
        Image(systemName: "info.circle.fill")
          .font(.system(size: 30, weight: .regular))
          .foregroundColor(.blue)
      }
      .buttonStyle(.plain)
      .simultaneousGesture(TapGesture().onEnded {
        triggerLightHaptic()
      })
    }
    .padding(.horizontal, 12)
    .padding(.top, 4)
    .padding(.bottom, 6)
    .background(.black)
  }
}

struct UIOptions: View {
  @EnvironmentObject var viewModel: ScorigamiViewModel
  
  @State var refreshView = 0
  
  // place all the UI options at the bottom
  //
  var body: some View {
    VStack(spacing: 4) {
      Spacer().frame(height: 20)
      Text("Zoom in, then tap for score info")
        .bold()
        .foregroundColor(.white)
      Spacer().frame(height: 40)
      HStack {
        VStack {
          HStack {
            Spacer().frame(width: 50, alignment: .leading)
            Picker("", selection: $refreshView) {
              Text("Frequency").tag(Int(0))
              Text("Recency").tag(Int(1))
            }.pickerStyle(.segmented)
              .colorScheme(.dark)
              .frame(width: 200, height: 30)
              .onChange(of: refreshView) { tag in
                triggerLightHaptic()
                viewModel.setGradientType(type: tag)
              }
            Spacer().frame(maxWidth: .infinity, alignment: .trailing)
          }
        }
      }
      Spacer().frame(height: 7)
      GradientLegend()
      Spacer().frame(height: 7)
        .environmentObject(viewModel)
    }
    .background(.black)
    .frame(maxWidth: .infinity, alignment: .trailing)
  }
}

struct GradientLegend: View {
  @EnvironmentObject var viewModel: ScorigamiViewModel
  
  // the legend reflects frequency or recency and includes min/max values;
  // it also has two different color ramp options
  //
  var body: some View {
    let minMaxes = viewModel.getMinMaxes()
    let colorSlices = 42
    HStack (spacing: 2) {
      Spacer().frame(width: 1, alignment: .leading)
      Text(minMaxes[0])
        .font(.system(size: 12)).bold()
        .foregroundColor(.white)
        .frame(width: 30, alignment: .trailing)
        .padding(.trailing, 4)
        .padding(.leading, 20)
      if viewModel.colorMapType == .redSpecturm {
        HStack(spacing: 0) {
          ForEach(1...colorSlices, id: \.self) { box in
            Color.red
              .frame(width: 4, height: 20)
              .padding(0)
              .saturation(Double(box) * 2.5 / 100.0)
          }
        }.border(.white)
      } else { // else it is .fullSpectrum
        HStack {
          let grad = Gradient(colors: [.blue, .cyan, .green, .yellow, .red])
          LinearGradient(gradient: grad, startPoint: .leading, endPoint: .trailing)
            .frame(width: CGFloat(colorSlices) * 4.0, height: 20)
        }
      }
      // add the max for the legend, then the color map type button
      //
      Text(minMaxes[1]).font(.system(size: 12)).frame(width: 40).bold()
        .foregroundColor(.white)
      Button(action: {
        triggerLightHaptic()
        viewModel.changeColorMapType()
      }) {
        HStack{
          Text("Full Color")
            .bold()
            .font(.system(size: 12))
            .foregroundColor(.white)
          Image(systemName: viewModel.colorMapType == .fullSpectrum ?
                "checkmark.square": "square")
            .foregroundColor(.white)
        }
      }.frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 2)
      Spacer()
    }
  }
}

private func triggerLightHaptic() {
  let generator = UIImpactFeedbackGenerator(style: .light)
  generator.prepare()
  generator.impactOccurred()
}

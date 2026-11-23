//
//  ContentView.swift
//  Scorigami
//
//  Created by Paul Kelaita on 10/19/22.
//

import SwiftUI
import UIKit

private let bottomControlFontSize: CGFloat = 12
private let bottomControlFontWeight: Font.Weight = .semibold
private let bottomControlFont: Font = .system(size: bottomControlFontSize,
                                              weight: bottomControlFontWeight)
private let bottomControlIconSize: CGFloat = 18
private let rightControlWidth: CGFloat = 94
private let rightControlTrailing: CGFloat = 14
private let rightIconBox: CGFloat = 18
private let legendCaptionFont: Font = .system(size: 12, weight: .regular)
private let legendBarWidth: CGFloat = 168
private let legendLeadingPadding: CGFloat = 20
private let legendMinLabelWidth: CGFloat = 46
private let legendItemSpacing: CGFloat = 2

struct ContentView: View {
  
  @Environment(\.scenePhase) private var scenePhase
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
    }
    .onChange(of: scenePhase) { phase in
      if phase == .active {
        viewModel.handleAppDidBecomeActive()
      }
    }
    .navigationBarTitleDisplayMode(.inline)
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
      Spacer().frame(height: 8)
      Text("Zoom in, then tap for score info")
        .bold()
        .foregroundColor(.white)
      Spacer().frame(height: 40)
      HStack {
        VStack {
          HStack {
            Spacer().frame(width: 50, alignment: .leading)
            Picker("", selection: $refreshView) {
              Text("Frequency")
                .font(bottomControlFont)
                .tag(Int(0))
              Text("Recency")
                .font(bottomControlFont)
                .tag(Int(1))
            }.pickerStyle(.segmented)
              .colorScheme(.dark)
              .frame(minWidth: 0, maxWidth: 200)
              .frame(height: 30)
              .onChange(of: refreshView) { tag in
                triggerLightHaptic()
                viewModel.setGradientType(type: tag)
              }
            Spacer(minLength: 0)
            Button(action: {
              triggerLightHaptic()
              viewModel.requestResetAndRefresh()
            }) {
              HStack(spacing: 8) {
                Text("Reset")
                  .font(bottomControlFont)
                  .foregroundColor(.white)
                  .lineLimit(1)
                  .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "scope")
                  .font(.system(size: bottomControlIconSize, weight: bottomControlFontWeight))
                  .foregroundColor(.white)
                  .frame(width: rightIconBox, alignment: .trailing)
              }
              .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .frame(width: rightControlWidth, alignment: .trailing)
            .padding(.trailing, rightControlTrailing)
          }
        }
      }
      Spacer().frame(height: 7)
      VStack(spacing: 2) {
        GradientLegend()
        HStack(alignment: .top, spacing: 8) {
          LegendCaption()
          Button {
            triggerLightHaptic()
            viewModel.isAutoMapEnabled.toggle()
          } label: {
            HStack(spacing: 8) {
              Text("Auto Map")
                .font(bottomControlFont)
              Image(systemName: viewModel.isAutoMapEnabled ? "checkmark.square" : "square")
                .font(.system(size: bottomControlIconSize, weight: bottomControlFontWeight))
                .frame(width: rightIconBox, height: bottomControlIconSize, alignment: .trailing)
            }
            .foregroundColor(.white)
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityValue(viewModel.isAutoMapEnabled ? "On" : "Off")
        }
        .padding(.leading, legendLeadingPadding + legendMinLabelWidth + legendItemSpacing)
        .padding(.trailing, rightControlTrailing)
      }
      Spacer().frame(height: 7)
        .environmentObject(viewModel)
    }
    .background(.black)
    .frame(maxWidth: .infinity, alignment: .trailing)
  }
}

struct GradientLegend: View {
  @EnvironmentObject var viewModel: ScorigamiViewModel
  @State private var activeFrequencyHandle: FrequencyHandle?

  private enum FrequencyHandle {
    case lower, upper
  }
  
  // the legend reflects frequency or recency and includes min/max values;
  // it also has two different color ramp options
  //
  var body: some View {
    let minMaxes = viewModel.getMinMaxes()
    GeometryReader { geometry in
      let maxLabelWidth: CGFloat = 40
      let reservedWidth = legendLeadingPadding + legendMinLabelWidth + maxLabelWidth +
        rightControlWidth + rightControlTrailing + 4 * legendItemSpacing
      let barWidth = min(legendBarWidth, max(1, geometry.size.width - reservedWidth))

      HStack(spacing: legendItemSpacing) {
        Text(minMaxes[0])
          .font(bottomControlFont)
          .foregroundColor(.white)
          .frame(width: legendMinLabelWidth - 4, alignment: .trailing)
          .lineLimit(1)
          .padding(.trailing, 4)
        legendBar(colorSlices: 42, barWidth: barWidth)
        Text(minMaxes[1])
          .font(bottomControlFont)
          .foregroundColor(.white)
          .frame(width: maxLabelWidth)
          .lineLimit(1)
        Spacer(minLength: 0)
        Button(action: {
          triggerLightHaptic()
          viewModel.changeColorMapType()
        }) {
          HStack {
            Text("Full Color")
              .font(bottomControlFont)
              .foregroundColor(.white)
            Image(systemName: viewModel.colorMapType == .fullSpectrum ?
                  "checkmark.square": "square")
              .font(.system(size: bottomControlIconSize, weight: bottomControlFontWeight))
              .foregroundColor(.white)
              .frame(width: rightIconBox, alignment: .trailing)
          }
          .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: rightControlWidth, alignment: .trailing)
        .buttonStyle(.plain)
      }
      .padding(.leading, legendLeadingPadding)
      .padding(.trailing, rightControlTrailing)
    }
    .frame(height: 30)
  }
}

struct LegendCaption: View {
  @EnvironmentObject var viewModel: ScorigamiViewModel

  var body: some View {
    let captions = [
      "Colors follow the scores in view",
      "Move the sliders to show specific frequencies",
      "Move the slider to show scores since the selected year"
    ]
    let activeCaption = viewModel.isAutoMapEnabled ? 0 : (viewModel.gradientType == .frequency ? 1 : 2)
    ZStack(alignment: .topLeading) {
      ForEach(captions.indices, id: \.self) { index in
        Text(captions[index])
          .opacity(index == activeCaption ? 1 : 0)
          .accessibilityHidden(index != activeCaption)
      }
    }
    .font(legendCaptionFont)
    .foregroundColor(.white.opacity(0.78))
    .multilineTextAlignment(.leading)
    .frame(maxWidth: .infinity, minHeight: 14, alignment: .topLeading)
  }
}

extension GradientLegend {
  @ViewBuilder
  fileprivate func legendBar(colorSlices: Int, barWidth: CGFloat) -> some View {
    ZStack(alignment: .topLeading) {
      if viewModel.isAutoMapEnabled {
        autoMappedLegend(barWidth: barWidth)
      } else if viewModel.colorMapType == .redSpecturm {
        if viewModel.gradientType == .frequency {
          frequencyFilteredLegend(totalWidth: barWidth,
                                  colorSlices: colorSlices,
                                  useRedSpectrum: true)
        } else if viewModel.gradientType == .recency && viewModel.isRecencyFilterActive() {
          recencyFilteredLegend(totalWidth: barWidth,
                                colorSlices: colorSlices,
                                useRedSpectrum: true)
        } else {
          HStack(spacing: 0) {
            ForEach(1...colorSlices, id: \.self) { box in
              Color.red
                .frame(width: barWidth / CGFloat(colorSlices), height: 20)
                .padding(0)
                .saturation(Double(box) * 2.5 / 100.0)
            }
          }
          .border(.white)
        }
      } else {
        if viewModel.gradientType == .frequency {
          frequencyFilteredLegend(totalWidth: barWidth,
                                  colorSlices: colorSlices,
                                  useRedSpectrum: false)
        } else if viewModel.gradientType == .recency && viewModel.isRecencyFilterActive() {
          recencyFilteredLegend(totalWidth: barWidth,
                                colorSlices: colorSlices,
                                useRedSpectrum: false)
        } else {
          HStack {
            let grad = Gradient(colors: [.blue, .cyan, .green, .yellow, .red])
            LinearGradient(gradient: grad, startPoint: .leading, endPoint: .trailing)
              .frame(width: barWidth, height: 20)
          }
        }
      }

      if !viewModel.isAutoMapEnabled {
        if viewModel.gradientType == .frequency {
          frequencyRangeMarkers(totalWidth: barWidth)
        } else {
          recencyCutoffMarker(totalWidth: barWidth)
        }
      }
    }
    .frame(width: barWidth, height: 30, alignment: .topLeading)
  }

  @ViewBuilder
  private func autoMappedLegend(barWidth: CGFloat) -> some View {
    let domainStart = viewModel.gradientType == .frequency ? 1 : viewModel.model.earliestGameYear
    let domainEnd = viewModel.gradientType == .frequency ? viewModel.model.highestCounter : viewModel.getCurrentYear()
    let buckets = CGFloat(max(1, domainEnd - domainStart + 1))
    let gray = Color(white: 0.38)
    let fullColor = viewModel.colorMapType == .fullSpectrum

    ScorigamiViewModel.filteredOutRangeColor
      .frame(width: barWidth, height: 20)
    if let range = viewModel.autoMapRange {
      let lower = min(1, max(0, CGFloat(range.lowerBound - domainStart) / buckets))
      let upper = min(1, max(lower, CGFloat(range.upperBound - domainStart + 1) / buckets))
      let colors: [Color] = fullColor ? [.blue, .cyan, .green, .yellow, .red] : [gray, .red]
      if range.lowerBound == range.upperBound {
        (fullColor ? Color.green : Color(red: 0.69, green: 0.19, blue: 0.19))
          .frame(width: (upper - lower) * barWidth, height: 20)
          .offset(x: lower * barWidth)
      } else {
        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
          .frame(width: (upper - lower) * barWidth, height: 20)
          .offset(x: lower * barWidth)
      }
      frequencyMarker(at: lower * barWidth, totalWidth: barWidth, showsHandle: false)
      frequencyMarker(at: upper * barWidth, totalWidth: barWidth, showsHandle: false)
    }
    Rectangle()
      .strokeBorder(.white)
      .frame(width: barWidth, height: 20)
  }

  @ViewBuilder
  fileprivate func frequencyFilteredLegend(totalWidth: CGFloat,
                                           colorSlices: Int,
                                           useRedSpectrum: Bool) -> some View {
    let totalBuckets = max(1, viewModel.model.highestCounter)
    let lowerFraction = CGFloat(viewModel.selectedFrequencyStartCount - 1) / CGFloat(totalBuckets)
    let upperFraction = CGFloat(viewModel.selectedFrequencyEndCount) / CGFloat(totalBuckets)
    let clampedLower = min(max(lowerFraction, 0.0), 1.0)
    let clampedUpper = min(max(upperFraction, clampedLower), 1.0)
    let lowerWidth = totalWidth * clampedLower
    let activeWidth = totalWidth * (clampedUpper - clampedLower)
    let upperWidth = max(0.0, totalWidth - lowerWidth - activeWidth)

    HStack(spacing: 0) {
      ScorigamiViewModel.filteredOutRangeColor
        .frame(width: lowerWidth, height: 20)
      if useRedSpectrum {
        HStack(spacing: 0) {
          ForEach(1...colorSlices, id: \.self) { box in
            Color.red
              .frame(width: activeWidth / CGFloat(colorSlices), height: 20)
              .padding(0)
              .saturation(Double(box) * 2.5 / 100.0)
          }
        }
      } else {
        let grad = Gradient(colors: [.blue, .cyan, .green, .yellow, .red])
        LinearGradient(gradient: grad, startPoint: .leading, endPoint: .trailing)
          .frame(width: activeWidth, height: 20)
      }
      ScorigamiViewModel.filteredOutRangeColor
        .frame(width: upperWidth, height: 20)
    }
    .frame(width: totalWidth, height: 20, alignment: .leading)
    .border(.white)
  }

  @ViewBuilder
  fileprivate func recencyFilteredLegend(totalWidth: CGFloat,
                                         colorSlices: Int,
                                         useRedSpectrum: Bool) -> some View {
    let currentYear = Double(viewModel.getCurrentYear())
    let earliestYear = Double(viewModel.model.earliestGameYear)
    let selectedYear = Double(viewModel.selectedRecencyStartYear)
    let totalRange = max(1.0, currentYear - earliestYear)
    let excludedFraction = min(max((selectedYear - earliestYear) / totalRange, 0.0), 1.0)
    let excludedWidth = totalWidth * excludedFraction
    let activeWidth = max(0.0, totalWidth - excludedWidth)

    HStack(spacing: 0) {
      ScorigamiViewModel.filteredOutRangeColor
        .frame(width: excludedWidth, height: 20)
      if useRedSpectrum {
        HStack(spacing: 0) {
          ForEach(1...colorSlices, id: \.self) { box in
            Color.red
              .frame(width: activeWidth / CGFloat(colorSlices), height: 20)
              .padding(0)
              .saturation(Double(box) * 2.5 / 100.0)
          }
        }
      } else {
        let grad = Gradient(colors: [.blue, .cyan, .green, .yellow, .red])
        LinearGradient(gradient: grad, startPoint: .leading, endPoint: .trailing)
          .frame(width: activeWidth, height: 20)
      }
    }
    .frame(width: totalWidth, height: 20, alignment: .leading)
    .border(.white)
  }

  @ViewBuilder
  fileprivate func recencyCutoffMarker(totalWidth: CGFloat) -> some View {
    let earliestYear = viewModel.model.earliestGameYear
    let currentYear = viewModel.getCurrentYear()
    let range = max(1, currentYear - earliestYear)
    let fraction = CGFloat(viewModel.selectedRecencyStartYear - earliestYear) / CGFloat(range)
    let clampedFraction = min(max(fraction, 0), 1)
    let x = min(max(clampedFraction * totalWidth, 0), totalWidth)
    let lineWidth: CGFloat = 2
    let knobSize: CGFloat = 8
    let lineOffsetX = min(max(x - (lineWidth / 2.0), 0), max(totalWidth - lineWidth, 0))
    let knobCenterX = lineOffsetX + (lineWidth / 2.0)
    let knobOffsetX = min(max(knobCenterX - (knobSize / 2.0), 0), max(totalWidth - knobSize, 0))

    ZStack(alignment: .topLeading) {
      Rectangle()
        .fill(.clear)
        .frame(width: totalWidth, height: 30)
        .contentShape(Rectangle())

      Rectangle()
        .fill(.white)
        .frame(width: lineWidth, height: 20)
        .offset(x: lineOffsetX,
                y: 0)

      Circle()
        .fill(.white)
        .frame(width: knobSize, height: knobSize)
        .offset(x: knobOffsetX,
                y: 20)
    }
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          let location = min(max(value.location.x, 0), totalWidth)
          let newFraction = totalWidth > 0 ? location / totalWidth : 0
          let year = earliestYear + Int(CGFloat(range) * newFraction)
          viewModel.updateRecencyStartYear(year)
        }
        .onEnded { _ in
          triggerLightHaptic()
        }
    )
  }

  @ViewBuilder
  fileprivate func frequencyRangeMarkers(totalWidth: CGFloat) -> some View {
    let totalBuckets = max(1, viewModel.model.highestCounter)
    let lowerFraction = CGFloat(viewModel.selectedFrequencyStartCount - 1) / CGFloat(totalBuckets)
    let upperFraction = CGFloat(viewModel.selectedFrequencyEndCount) / CGFloat(totalBuckets)
    let lowerX = min(max(lowerFraction * totalWidth, 0), totalWidth)
    let upperX = min(max(upperFraction * totalWidth, 0), totalWidth)

    ZStack(alignment: .topLeading) {
      Rectangle()
        .fill(.clear)
        .frame(width: totalWidth, height: 30)
        .contentShape(Rectangle())

      frequencyMarker(at: lowerX, totalWidth: totalWidth)
      frequencyMarker(at: upperX, totalWidth: totalWidth)
    }
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          let location = min(max(value.location.x, 0), totalWidth)
          if activeFrequencyHandle == nil {
            activeFrequencyHandle = abs(location - lowerX) <= abs(location - upperX) ? .lower : .upper
          }
          switch activeFrequencyHandle {
          case .lower:
            let lowerCount = min(max(frequencyLowerCount(for: location,
                                                         totalWidth: totalWidth,
                                                         totalBuckets: totalBuckets), 1),
                                 viewModel.selectedFrequencyEndCount)
            viewModel.updateFrequencyRange(startCount: lowerCount,
                                           endCount: viewModel.selectedFrequencyEndCount)
          case .upper:
            let upperCount = max(min(frequencyUpperCount(for: location,
                                                         totalWidth: totalWidth,
                                                         totalBuckets: totalBuckets),
                                     viewModel.model.highestCounter),
                                 viewModel.selectedFrequencyStartCount)
            viewModel.updateFrequencyRange(startCount: viewModel.selectedFrequencyStartCount,
                                           endCount: upperCount)
          case .none:
            break
          }
        }
        .onEnded { _ in
          activeFrequencyHandle = nil
          triggerLightHaptic()
        }
    )
  }

  private func frequencyMarker(at x: CGFloat, totalWidth: CGFloat, showsHandle: Bool = true) -> some View {
    let lineWidth: CGFloat = 2
    let knobSize: CGFloat = 8
    let lineOffsetX = min(max(x - (lineWidth / 2.0), 0), max(totalWidth - lineWidth, 0))
    let knobCenterX = lineOffsetX + (lineWidth / 2.0)
    let knobOffsetX = min(max(knobCenterX - (knobSize / 2.0), 0), max(totalWidth - knobSize, 0))

    return ZStack(alignment: .topLeading) {
      Rectangle()
        .fill(.white)
        .frame(width: lineWidth, height: 20)
        .offset(x: lineOffsetX,
                y: 0)

      if showsHandle {
        Circle()
          .fill(.white)
          .frame(width: knobSize, height: knobSize)
          .offset(x: knobOffsetX,
                  y: 20)
      }
    }
  }

  private func frequencyLowerCount(for location: CGFloat,
                                   totalWidth: CGFloat,
                                   totalBuckets: Int) -> Int {
    guard totalWidth > 0 else { return 1 }
    let fraction = min(max(location / totalWidth, 0), 1)
    return Int(floor(fraction * CGFloat(totalBuckets))) + 1
  }

  private func frequencyUpperCount(for location: CGFloat,
                                   totalWidth: CGFloat,
                                   totalBuckets: Int) -> Int {
    guard totalWidth > 0 else { return totalBuckets }
    let fraction = min(max(location / totalWidth, 0), 1)
    return max(1, Int(ceil(fraction * CGFloat(totalBuckets))))
  }
}

private func triggerLightHaptic() {
  let generator = UIImpactFeedbackGenerator(style: .light)
  generator.prepare()
  generator.impactOccurred()
}

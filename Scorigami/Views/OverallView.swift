//
//  OverallView.swift
//  Scorigami
//
//  Created by Paul Kelaita on 11/15/22.
//

import SwiftUI
import UIKit

struct OverallView: View {
  @EnvironmentObject var viewModel: ScorigamiViewModel

  @State private var selectedScore: ScoreDetails?

  @State private var zoomScale: CGFloat = 1.0
  @State private var lastZoomScale: CGFloat = 1.0
  @State private var panOffset: CGSize = .zero
  @State private var lastPanOffset: CGSize = .zero
  @State private var isPinching = false
  @State private var pinchAnchorPoint: CGPoint = .zero
  @State private var programmaticZoomTask: Task<Void, Never>?

  private let axisWidth: CGFloat = 24.0
  private let topAxisHeight: CGFloat = 30.0

  var body: some View {
    GeometryReader { geo in
      let cellSize = Devices.getFrameHeight()
      let highestWinningScore = viewModel.getHighestWinningScore()
      let highestLosingScore = viewModel.getHighestLosingScore()
      let boardWidth = CGFloat(highestWinningScore + 1) * cellSize
      let boardHeight = CGFloat(highestLosingScore + 1) * cellSize
      let boardScaledWidth = boardWidth * zoomScale
      let boardScaledHeight = boardHeight * zoomScale
      let plotWidth = max(0.0, geo.size.width - axisWidth)
      let plotHeight = max(0.0, geo.size.height - topAxisHeight)
      let effectiveOffset = clampedOffset(offset: panOffset,
                                          scale: zoomScale,
                                          boardWidth: boardWidth,
                                          boardHeight: boardHeight,
                                          plotWidth: plotWidth,
                                          plotHeight: plotHeight)

      ZStack(alignment: .topLeading) {
        Text("Winning Score")
          .frame(width: geo.size.width, alignment: .center)
          .font(.system(size: 12))
          .foregroundColor(.white)
          .bold()
          .offset(x: 0, y: 0)

        TopAxisLabels(highestWinningScore: highestWinningScore,
                      cellSize: cellSize,
                      axisWidth: axisWidth,
                      topAxisHeight: topAxisHeight,
                      zoomScale: zoomScale,
                      panOffset: effectiveOffset,
                      viewportWidth: geo.size.width)

        LeftAxisLabels(highestLosingScore: highestLosingScore,
                       cellSize: cellSize,
                       axisWidth: axisWidth,
                       topAxisHeight: topAxisHeight,
                       zoomScale: zoomScale,
                       panOffset: effectiveOffset,
                       viewportHeight: geo.size.height)

        ZStack(alignment: .topLeading) {
          OverviewBoard(cellSize: cellSize,
                        zoomScale: zoomScale,
                        plotWidth: plotWidth,
                        plotHeight: plotHeight,
                        panOffset: effectiveOffset,
                        onSelect: { cell, winningScore, losingScore in
                          showScoreDetails(cell: cell,
                                           winningScore: winningScore,
                                           losingScore: losingScore,
                                           cellSize: cellSize,
                                           boardWidth: boardWidth,
                                           boardHeight: boardHeight,
                                           plotWidth: plotWidth,
                                           plotHeight: plotHeight)
                        })
            .environmentObject(viewModel)
            .frame(width: boardScaledWidth, height: boardScaledHeight, alignment: .topLeading)
            .offset(x: effectiveOffset.width, y: effectiveOffset.height)
        }
        .frame(width: plotWidth, height: plotHeight, alignment: .topLeading)
        .clipped()
        .offset(x: axisWidth, y: topAxisHeight)
        .contentShape(Rectangle())
        .overlay(
          PinchZoomCaptureView(
            onBegan: { location in
              isPinching = true
              pinchAnchorPoint = location
              lastZoomScale = zoomScale
              lastPanOffset = panOffset
            },
            onChanged: { magnification, location in
              let nextScale = clampedScale(lastZoomScale * magnification)
              let adjustedOffset = adjustedOffsetForScale(oldScale: lastZoomScale,
                                                          newScale: nextScale,
                                                          oldOffset: lastPanOffset,
                                                          focusPoint: pinchAnchorPoint == .zero ? location : pinchAnchorPoint)
              zoomScale = nextScale
              panOffset = clampedOffset(offset: adjustedOffset,
                                        scale: zoomScale,
                                        boardWidth: boardWidth,
                                        boardHeight: boardHeight,
                                        plotWidth: plotWidth,
                                        plotHeight: plotHeight)
            },
            onEnded: {
              lastZoomScale = zoomScale
              panOffset = clampedOffset(offset: panOffset,
                                        scale: zoomScale,
                                        boardWidth: boardWidth,
                                        boardHeight: boardHeight,
                                        plotWidth: plotWidth,
                                        plotHeight: plotHeight)
              lastPanOffset = panOffset
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                isPinching = false
                pinchAnchorPoint = .zero
              }
            }
          )
        )
        .simultaneousGesture(dragGesture(boardWidth: boardWidth,
                                         boardHeight: boardHeight,
                                         plotWidth: plotWidth,
                                         plotHeight: plotHeight))
        .simultaneousGesture(tapGesture(boardWidth: boardWidth,
                                        boardHeight: boardHeight,
                                        plotWidth: plotWidth,
                                        plotHeight: plotHeight,
                                        cellSize: cellSize))
      }
      .onChange(of: geo.size) { _ in
        let adjusted = clampedOffset(offset: panOffset,
                                     scale: zoomScale,
                                     boardWidth: boardWidth,
                                     boardHeight: boardHeight,
                                     plotWidth: plotWidth,
                                     plotHeight: plotHeight)
        panOffset = adjusted
        lastPanOffset = adjusted
      }
      .onChange(of: viewModel.resetRequestID) { _ in
        resetToOverview(boardWidth: boardWidth,
                        boardHeight: boardHeight,
                        plotWidth: plotWidth,
                        plotHeight: plotHeight)
      }
      .background(.black)
    }
    .sheet(item: $selectedScore) { details in
      GameScoreSheet(details: details)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
  }

  private func dragGesture(boardWidth: CGFloat,
                           boardHeight: CGFloat,
                           plotWidth: CGFloat,
                           plotHeight: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 3, coordinateSpace: .local)
      .onChanged { value in
        if isPinching { return }
        let candidate = CGSize(width: lastPanOffset.width + value.translation.width,
                               height: lastPanOffset.height + value.translation.height)
        panOffset = clampedOffset(offset: candidate,
                                  scale: zoomScale,
                                  boardWidth: boardWidth,
                                  boardHeight: boardHeight,
                                  plotWidth: plotWidth,
                                  plotHeight: plotHeight)
      }
      .onEnded { value in
        if isPinching {
          lastPanOffset = panOffset
          return
        }
        let coastMultiplier: CGFloat = 0.6
        let predictedDelta = CGSize(width: value.predictedEndTranslation.width - value.translation.width,
                                    height: value.predictedEndTranslation.height - value.translation.height)
        let target = CGSize(width: panOffset.width + predictedDelta.width * coastMultiplier,
                            height: panOffset.height + predictedDelta.height * coastMultiplier)
        let clampedTarget = clampedOffset(offset: target,
                                          scale: zoomScale,
                                          boardWidth: boardWidth,
                                          boardHeight: boardHeight,
                                          plotWidth: plotWidth,
                                          plotHeight: plotHeight)
        withAnimation(.interpolatingSpring(stiffness: 170, damping: 28)) {
          panOffset = clampedTarget
        }
        lastPanOffset = panOffset
      }
  }

  private func tapGesture(boardWidth: CGFloat,
                          boardHeight: CGFloat,
                          plotWidth: CGFloat,
                          plotHeight: CGFloat,
                          cellSize: CGFloat) -> some Gesture {
    SpatialTapGesture(coordinateSpace: .local)
      .onEnded { value in
        if zoomScale < 2.35 {
          handleTap(at: value.location,
                    boardWidth: boardWidth,
                    boardHeight: boardHeight,
                    plotWidth: plotWidth,
                    plotHeight: plotHeight,
                    cellSize: cellSize)
        }
      }
  }

  private func adjustedOffsetForScale(oldScale: CGFloat,
                                      newScale: CGFloat,
                                      oldOffset: CGSize,
                                      focusPoint: CGPoint) -> CGSize {
    let contentX = (focusPoint.x - oldOffset.width) / max(oldScale, 0.001)
    let contentY = (focusPoint.y - oldOffset.height) / max(oldScale, 0.001)
    return CGSize(width: focusPoint.x - (contentX * newScale),
                  height: focusPoint.y - (contentY * newScale))
  }

  private func clampedScale(_ rawScale: CGFloat) -> CGFloat {
    min(9.0, max(1.0, rawScale))
  }

  private func clampedOffset(offset: CGSize,
                             scale: CGFloat,
                             boardWidth: CGFloat,
                             boardHeight: CGFloat,
                             plotWidth: CGFloat,
                             plotHeight: CGFloat) -> CGSize {
    let minX = min(0.0, plotWidth - (boardWidth * scale))
    let minY = min(0.0, plotHeight - (boardHeight * scale))
    let x = min(0.0, max(minX, offset.width))
    let y = min(0.0, max(minY, offset.height))
    return CGSize(width: x, height: y)
  }

  private func showScoreDetails(cell: ScorigamiViewModel.Cell,
                                winningScore: Int,
                                losingScore: Int,
                                cellSize: CGFloat,
                                boardWidth: CGFloat,
                                boardHeight: CGFloat,
                                plotWidth: CGFloat,
                                plotHeight: CGFloat) {
    let haptic = UIImpactFeedbackGenerator(style: .light)
    haptic.prepare()
    haptic.impactOccurred()

    let didAnimateZoom = zoomToCellIfNeeded(winningScore: winningScore,
                                            losingScore: losingScore,
                                            cellSize: cellSize,
                                            boardWidth: boardWidth,
                                            boardHeight: boardHeight,
                                            plotWidth: plotWidth,
                                            plotHeight: plotHeight)

    if didAnimateZoom {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
        selectedScore = ScoreDetails(cell: cell)
      }
    } else {
      selectedScore = ScoreDetails(cell: cell)
    }
  }

  private func handleTap(at location: CGPoint,
                         boardWidth: CGFloat,
                         boardHeight: CGFloat,
                         plotWidth: CGFloat,
                         plotHeight: CGFloat,
                         cellSize: CGFloat) {
    // This gesture lives on a view that is visually shifted by the axis offsets.
    // Normalize back into plot-space before converting to board coordinates.
    let normalizedLocation = CGPoint(x: location.x - axisWidth,
                                     y: location.y - topAxisHeight)

    let scaledCell = cellSize * zoomScale
    if scaledCell <= 0 {
      return
    }
    let effectiveOffset = clampedOffset(offset: panOffset,
                                        scale: zoomScale,
                                        boardWidth: boardWidth,
                                        boardHeight: boardHeight,
                                        plotWidth: plotWidth,
                                        plotHeight: plotHeight)
    let xOnBoard = (normalizedLocation.x - effectiveOffset.width) / scaledCell
    let yOnBoard = (normalizedLocation.y - effectiveOffset.height) / scaledCell
    let winningScore = Int(floor(xOnBoard))
    let losingScore = Int(floor(yOnBoard))
    if winningScore < 0 || losingScore < 0 {
      return
    }
    if losingScore > viewModel.getHighestLosingScore() || winningScore > viewModel.getHighestWinningScore() {
      return
    }
    let row = viewModel.getGamesForLosingScore(losingScore: losingScore)
    if winningScore >= row.count {
      return
    }
    let cell = row[winningScore]
    if cell.label != "" {
      showScoreDetails(cell: cell,
                       winningScore: winningScore,
                       losingScore: losingScore,
                       cellSize: cellSize,
                       boardWidth: boardWidth,
                       boardHeight: boardHeight,
                       plotWidth: plotWidth,
                       plotHeight: plotHeight)
    }
  }

  private func zoomToCellIfNeeded(winningScore: Int,
                                  losingScore: Int,
                                  cellSize: CGFloat,
                                  boardWidth: CGFloat,
                                  boardHeight: CGFloat,
                                  plotWidth: CGFloat,
                                  plotHeight: CGFloat) -> Bool {
    let targetScale = clampedScale(9.0)
    if zoomScale >= targetScale - 0.01 {
      return false
    }

    let targetCell = cellSize * targetScale
    let cellCenterX = CGFloat(winningScore) * targetCell + (targetCell / 2.0)
    let cellCenterY = CGFloat(losingScore) * targetCell + (targetCell / 2.0)
    let rawOffset = CGSize(width: (plotWidth / 2.0) - cellCenterX,
                           height: (plotHeight / 2.0) - cellCenterY)
    let clampedTargetOffset = clampedOffset(offset: rawOffset,
                                            scale: targetScale,
                                            boardWidth: boardWidth,
                                            boardHeight: boardHeight,
                                            plotWidth: plotWidth,
                                            plotHeight: plotHeight)
    animateZoomAndPan(toScale: targetScale,
                      toOffset: clampedTargetOffset)
    return true
  }

  private func animateZoomAndPan(toScale: CGFloat,
                                 toOffset: CGSize,
                                 duration: Double = 0.65) {
    let startScale = zoomScale
    let startOffset = panOffset
    programmaticZoomTask?.cancel()
    programmaticZoomTask = Task { @MainActor in
      let frameCount = 40
      for frame in 0...frameCount {
        if Task.isCancelled { return }
        let t = CGFloat(frame) / CGFloat(frameCount)
        let eased = t * t * (3.0 - (2.0 * t)) // smoothstep
        zoomScale = startScale + (toScale - startScale) * eased
        panOffset = CGSize(width: startOffset.width + (toOffset.width - startOffset.width) * eased,
                           height: startOffset.height + (toOffset.height - startOffset.height) * eased)
        if frame < frameCount {
          try? await Task.sleep(nanoseconds: UInt64((duration / Double(frameCount)) * 1_000_000_000))
        }
      }
      zoomScale = toScale
      panOffset = toOffset
      lastZoomScale = toScale
      lastPanOffset = toOffset
      programmaticZoomTask = nil
    }
  }

  private func resetToOverview(boardWidth: CGFloat,
                               boardHeight: CGFloat,
                               plotWidth: CGFloat,
                               plotHeight: CGFloat) {
    let targetScale: CGFloat = 1.0
    let targetOffset = clampedOffset(offset: .zero,
                                     scale: targetScale,
                                     boardWidth: boardWidth,
                                     boardHeight: boardHeight,
                                     plotWidth: plotWidth,
                                     plotHeight: plotHeight)
    if abs(zoomScale - targetScale) < 0.001 &&
        abs(panOffset.width - targetOffset.width) < 0.001 &&
        abs(panOffset.height - targetOffset.height) < 0.001 {
      return
    }
    animateZoomAndPan(toScale: targetScale,
                      toOffset: targetOffset,
                      duration: 0.55)
  }
}

struct ScoreDetails: Identifiable {
  let id = UUID()
  let score: String
  let occurrences: Int
  let gamesUrl: String
  let lastGame: String
  let plural: String

  init(cell: ScorigamiViewModel.Cell) {
    score = cell.label
    occurrences = cell.occurrences
    gamesUrl = cell.gamesUrl
    lastGame = cell.lastGame
    plural = cell.plural
  }
}

struct GameScoreSheet: View {
  let details: ScoreDetails
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(details.score)
        .font(.system(size: 30, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .center)
      if details.occurrences > 0 {
        Text("This score has happened \(details.occurrences) time\(details.plural).")
          .font(.system(size: 17, weight: .semibold))
        Text("Most recent game:")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
        Text(details.lastGame)
          .font(.system(size: 16))
        if let url = URL(string: details.gamesUrl), !details.gamesUrl.isEmpty {
          Link(destination: url) {
            Text("View games")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .padding(.top, 6)
        }
      } else {
        Text("SCORIGAMI!")
          .font(.system(size: 22, weight: .heavy))
          .foregroundColor(.orange)
        Text("No game has ever ended with this score...yet.")
          .font(.system(size: 17, weight: .semibold))
      }
      Spacer(minLength: 0)
      Button("Done") {
        dismiss()
      }
      .frame(maxWidth: .infinity)
      .buttonStyle(.bordered)
    }
    .padding(20)
  }
}

struct TopAxisLabels: View {
  let highestWinningScore: Int
  let cellSize: CGFloat
  let axisWidth: CGFloat
  let topAxisHeight: CGFloat
  let zoomScale: CGFloat
  let panOffset: CGSize
  let viewportWidth: CGFloat

  var body: some View {
    let ticks = winningTicks(maxScore: highestWinningScore)
    ZStack(alignment: .topLeading) {
      ForEach(ticks, id: \.self) { score in
        let scaledCell = cellSize * zoomScale
        let xCenter = axisWidth + panOffset.width + (CGFloat(score) * scaledCell) + (scaledCell / 2.0)
        if xCenter >= axisWidth - 26.0 && xCenter <= viewportWidth {
          Text(String(score))
            .font(.system(size: 10))
            .foregroundColor(.white)
            .position(x: xCenter, y: topAxisHeight - 9.0)
        }
      }
    }
  }

  private func winningTicks(maxScore: Int) -> [Int] {
    let step = zoomScale > 2.6 ? 1 : 5
    return Array(stride(from: 0, through: maxScore, by: step))
  }
}

struct LeftAxisLabels: View {
  let highestLosingScore: Int
  let cellSize: CGFloat
  let axisWidth: CGFloat
  let topAxisHeight: CGFloat
  let zoomScale: CGFloat
  let panOffset: CGSize
  let viewportHeight: CGFloat

  var body: some View {
    let ticks = losingTicks(maxScore: highestLosingScore)
    ZStack(alignment: .topLeading) {
      ForEach(ticks, id: \.self) { score in
        let scaledCell = cellSize * zoomScale
        let yCenter = topAxisHeight + panOffset.height + (CGFloat(score) * scaledCell) + (scaledCell / 2.0)
        if yCenter >= topAxisHeight - 6.0 && yCenter <= viewportHeight {
          Text(String(score))
            .font(.system(size: 10))
            .foregroundColor(.white)
            .frame(width: axisWidth, alignment: .center)
            .position(x: axisWidth / 2.0, y: yCenter)
        }
      }
    }
  }

  private func losingTicks(maxScore: Int) -> [Int] {
    let step = zoomScale > 2.6 ? 1 : 5
    return Array(stride(from: 0, through: maxScore, by: step))
  }
}

struct OverviewBoard: View {
  @EnvironmentObject var viewModel: ScorigamiViewModel

  let cellSize: CGFloat
  let zoomScale: CGFloat
  let plotWidth: CGFloat
  let plotHeight: CGFloat
  let panOffset: CGSize
  let onSelect: (ScorigamiViewModel.Cell, Int, Int) -> Void

  var body: some View {
    let showLabels = zoomScale >= 2.35
    let scaledCell = cellSize * zoomScale
    let textSize = min(14.0, max(4.5, scaledCell * 0.24))
    let showOccurrenceLine = scaledCell >= 34.0
    let occurrenceTextSize = max(4.0, textSize * 0.72)
    let roundedCells = zoomScale >= 3.0
    let cellInset = roundedCells ? min(1.5, scaledCell * 0.08) : 0.25
    let cornerRadius = roundedCells ? min(4.0, scaledCell * 0.18) : 0.0
    let maxWinning = viewModel.getHighestWinningScore()
    let maxLosing = viewModel.getHighestLosingScore()
    let startCol = max(0, Int(floor(-panOffset.width / max(scaledCell, 0.001))))
    let endCol = min(maxWinning, Int(ceil((plotWidth - panOffset.width) / max(scaledCell, 0.001))))
    let startRow = max(0, Int(floor(-panOffset.height / max(scaledCell, 0.001))))
    let endRow = min(maxLosing, Int(ceil((plotHeight - panOffset.height) / max(scaledCell, 0.001))))

    ZStack(alignment: .topLeading) {
      Canvas { context, _ in
        for losingScore in 0...maxLosing {
          let row = viewModel.getGamesForLosingScore(losingScore: losingScore)
          for winningScore in 0..<row.count {
            let cell = row[winningScore]
            let color = resolvedFillColor(cell: cell)
            let rect = CGRect(x: CGFloat(winningScore) * scaledCell + cellInset,
                              y: CGFloat(losingScore) * scaledCell + cellInset,
                              width: max(0, scaledCell - (2.0 * cellInset)),
                              height: max(0, scaledCell - (2.0 * cellInset)))
            if cornerRadius > 0 {
              let rounded = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              context.fill(rounded.path(in: rect), with: .color(color))
            } else {
              context.fill(Path(rect), with: .color(color))
            }
          }
        }
      }
      if showLabels && endCol >= startCol && endRow >= startRow {
        ForEach(startRow...endRow, id: \.self) { losingScore in
          let row = viewModel.getGamesForLosingScore(losingScore: losingScore)
          ForEach(startCol...min(endCol, row.count - 1), id: \.self) { winningScore in
            let cell = row[winningScore]
            if cell.label != "" {
              if showOccurrenceLine {
                ZStack {
                  Text(cell.label)
                    .font(.system(size: textSize, weight: .bold))
                    .minimumScaleFactor(0.2)
                    .lineLimit(1)
                  if let detail = detailText(for: cell) {
                    Text(detail)
                      .font(.system(size: occurrenceTextSize, weight: .semibold))
                      .minimumScaleFactor(0.1)
                      .lineLimit(1)
                      .allowsTightening(true)
                      .multilineTextAlignment(.trailing)
                      .frame(width: scaledCell * 0.78, alignment: .trailing)
                      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                      .padding(.trailing, max(1.0, scaledCell * 0.08))
                      .padding(.bottom, max(1.0, scaledCell * 0.06))
                  }
                }
                .foregroundColor(viewModel.getTextColor(cell: cell))
                .frame(width: scaledCell * 0.92, height: scaledCell * 0.88, alignment: .center)
                .position(x: CGFloat(winningScore) * scaledCell + (scaledCell / 2.0),
                  y: CGFloat(losingScore) * scaledCell + (scaledCell / 2.0))
                .onTapGesture {
                  onSelect(cell, winningScore, losingScore)
                }
              } else {
                Text(cell.label)
                  .font(.system(size: textSize, weight: .bold))
                  .minimumScaleFactor(0.2)
                  .lineLimit(1)
                  .foregroundColor(viewModel.getTextColor(cell: cell))
                  .position(x: CGFloat(winningScore) * scaledCell + (scaledCell / 2.0),
                            y: CGFloat(losingScore) * scaledCell + (scaledCell / 2.0))
                  .onTapGesture {
                    onSelect(cell, winningScore, losingScore)
                  }
              }
            }
          }
        }
      }
    }
    .drawingGroup(opaque: true)
    .background(.black)
  }

  private func resolvedFillColor(cell: ScorigamiViewModel.Cell) -> Color {
    if cell.occurrences == 0 {
      return .black
    }

    let colorAndSat = viewModel.getColorAndSat(cell: cell)
    let baseColor = colorAndSat.0
    let sat = CGFloat(max(0.0, min(1.0, colorAndSat.1)))
    let baseUIColor = UIColor(baseColor)

    if viewModel.colorMapType == .redSpecturm {
      let start = UIColor(white: 0.38, alpha: 1.0)
      let end = UIColor.red
      var sr: CGFloat = 0
      var sg: CGFloat = 0
      var sb: CGFloat = 0
      var sa: CGFloat = 0
      var er: CGFloat = 0
      var eg: CGFloat = 0
      var eb: CGFloat = 0
      var ea: CGFloat = 0
      start.getRed(&sr, green: &sg, blue: &sb, alpha: &sa)
      end.getRed(&er, green: &eg, blue: &eb, alpha: &ea)

      let t = sat
      let r = sr + (er - sr) * t
      let g = sg + (eg - sg) * t
      let b = sb + (eb - sb) * t
      return Color(red: Double(r), green: Double(g), blue: Double(b))
    }

    let uiColor = baseUIColor
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0

    if uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
      return Color(uiColor: UIColor(hue: hue,
                                    saturation: saturation * sat,
                                    brightness: brightness,
                                    alpha: alpha))
    }
    return baseColor
  }

  private func detailText(for cell: ScorigamiViewModel.Cell) -> String? {
    guard cell.occurrences > 0 else { return nil }
    if viewModel.gradientType == .recency {
      return "(\(viewModel.getMostRecentYear(gameDesc: cell.lastGame)))"
    }
    return "(\(cell.occurrences))"
  }
}

private struct PinchZoomCaptureView: UIViewRepresentable {
  var onBegan: (CGPoint) -> Void
  var onChanged: (CGFloat, CGPoint) -> Void
  var onEnded: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onBegan: onBegan, onChanged: onChanged, onEnded: onEnded)
  }

  func makeUIView(context: Context) -> UIView {
    let view = UIView(frame: .zero)
    view.backgroundColor = .clear
    view.isUserInteractionEnabled = false
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    DispatchQueue.main.async {
      guard let host = uiView.superview else { return }
      context.coordinator.installIfNeeded(on: host)
    }
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    private let onBegan: (CGPoint) -> Void
    private let onChanged: (CGFloat, CGPoint) -> Void
    private let onEnded: () -> Void
    private var pinchRecognizer: UIPinchGestureRecognizer?
    private weak var installedGestureView: UIView?
    private weak var targetHostView: UIView?
    private var pinchActive = false

    init(onBegan: @escaping (CGPoint) -> Void,
         onChanged: @escaping (CGFloat, CGPoint) -> Void,
         onEnded: @escaping () -> Void) {
      self.onBegan = onBegan
      self.onChanged = onChanged
      self.onEnded = onEnded
    }

    func installIfNeeded(on view: UIView) {
      let gestureView = view.window ?? view
      if installedGestureView === gestureView, targetHostView === view, pinchRecognizer != nil {
        return
      }
      if let oldView = installedGestureView, let recognizer = pinchRecognizer {
        oldView.removeGestureRecognizer(recognizer)
      }
      let recognizer = UIPinchGestureRecognizer(target: self,
                                                action: #selector(handlePinch(_:)))
      recognizer.cancelsTouchesInView = false
      recognizer.delegate = self
      gestureView.addGestureRecognizer(recognizer)
      pinchRecognizer = recognizer
      installedGestureView = gestureView
      targetHostView = view
    }

    @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
      guard let hostView = targetHostView else { return }
      let location = recognizer.location(in: hostView)
      switch recognizer.state {
      case .began:
        guard hostView.bounds.contains(location) else {
          pinchActive = false
          return
        }
        pinchActive = true
        onBegan(location)
      case .changed:
        guard pinchActive else { return }
        onChanged(recognizer.scale, location)
      case .ended, .cancelled, .failed:
        guard pinchActive else { return }
        pinchActive = false
        onEnded()
      default:
        break
      }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      true
    }
  }
}

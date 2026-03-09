//
//  OverallView.swift
//  Scorigami
//
//  Created by Paul Kelaita on 11/15/22.
//

import SwiftUI

struct OverallView: View {
  @EnvironmentObject var viewModel: ScorigamiViewModel

  @State private var selectedScore: ScoreDetails?

  @State private var zoomScale: CGFloat = 1.0
  @State private var lastZoomScale: CGFloat = 1.0
  @State private var panOffset: CGSize = .zero
  @State private var lastPanOffset: CGSize = .zero

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
                        onSelect: showScoreDetails)
            .environmentObject(viewModel)
            .frame(width: boardScaledWidth, height: boardScaledHeight, alignment: .topLeading)
            .offset(x: effectiveOffset.width, y: effectiveOffset.height)
        }
        .frame(width: plotWidth, height: plotHeight, alignment: .topLeading)
        .clipped()
        .offset(x: axisWidth, y: topAxisHeight)
        .contentShape(Rectangle())
        .gesture(dragGesture(boardWidth: boardWidth,
                             boardHeight: boardHeight,
                             plotWidth: plotWidth,
                             plotHeight: plotHeight)
          .simultaneously(with: zoomGesture(boardWidth: boardWidth,
                                            boardHeight: boardHeight,
                                            plotWidth: plotWidth,
                                            plotHeight: plotHeight)))
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
    DragGesture(minimumDistance: 8)
      .onChanged { value in
        let candidate = CGSize(width: lastPanOffset.width + value.translation.width,
                               height: lastPanOffset.height + value.translation.height)
        panOffset = clampedOffset(offset: candidate,
                                  scale: zoomScale,
                                  boardWidth: boardWidth,
                                  boardHeight: boardHeight,
                                  plotWidth: plotWidth,
                                  plotHeight: plotHeight)
      }
      .onEnded { _ in
        lastPanOffset = panOffset
      }
  }

  private func zoomGesture(boardWidth: CGFloat,
                           boardHeight: CGFloat,
                           plotWidth: CGFloat,
                           plotHeight: CGFloat) -> some Gesture {
    MagnificationGesture()
      .onChanged { value in
        let nextScale = clampedScale(lastZoomScale * value)
        let adjustedOffset = adjustedOffsetForScale(oldScale: lastZoomScale,
                                                    newScale: nextScale,
                                                    oldOffset: lastPanOffset,
                                                    plotWidth: plotWidth,
                                                    plotHeight: plotHeight)
        zoomScale = nextScale
        panOffset = clampedOffset(offset: adjustedOffset,
                                  scale: zoomScale,
                                  boardWidth: boardWidth,
                                  boardHeight: boardHeight,
                                  plotWidth: plotWidth,
                                  plotHeight: plotHeight)
      }
      .onEnded { value in
        zoomScale = clampedScale(lastZoomScale * value)
        lastZoomScale = zoomScale
        panOffset = clampedOffset(offset: panOffset,
                                  scale: zoomScale,
                                  boardWidth: boardWidth,
                                  boardHeight: boardHeight,
                                  plotWidth: plotWidth,
                                  plotHeight: plotHeight)
        lastPanOffset = panOffset
      }
  }

  private func adjustedOffsetForScale(oldScale: CGFloat,
                                      newScale: CGFloat,
                                      oldOffset: CGSize,
                                      plotWidth: CGFloat,
                                      plotHeight: CGFloat) -> CGSize {
    let centerX = plotWidth / 2.0
    let centerY = plotHeight / 2.0
    let contentX = (centerX - oldOffset.width) / max(oldScale, 0.001)
    let contentY = (centerY - oldOffset.height) / max(oldScale, 0.001)
    return CGSize(width: centerX - (contentX * newScale),
                  height: centerY - (contentY * newScale))
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

  private func showScoreDetails(cell: ScorigamiViewModel.Cell) {
    selectedScore = ScoreDetails(cell: cell)
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
        let x = axisWidth + panOffset.width + (CGFloat(score) * cellSize * zoomScale)
        if x >= axisWidth - 26.0 && x <= viewportWidth {
          Text(String(score))
            .font(.system(size: 10))
            .foregroundColor(.white)
            .offset(x: x, y: topAxisHeight - 14.0)
        }
      }
    }
  }

  private func winningTicks(maxScore: Int) -> [Int] {
    var ticks = Array(stride(from: 0, through: maxScore, by: 5))
    if ticks.last != maxScore {
      ticks.append(maxScore)
    }
    return ticks
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
        let y = topAxisHeight + panOffset.height + (CGFloat(score) * cellSize * zoomScale)
        if y >= topAxisHeight - 6.0 && y <= viewportHeight {
          Text(String(score))
            .font(.system(size: 10))
            .foregroundColor(.white)
            .frame(width: axisWidth - 2.0, alignment: .trailing)
            .offset(x: 0, y: y - 6.0)
        }
      }
    }
  }

  private func losingTicks(maxScore: Int) -> [Int] {
    var ticks = Array(stride(from: 0, through: maxScore, by: 5))
    if ticks.last != maxScore {
      ticks.append(maxScore)
    }
    return ticks
  }
}

struct OverviewBoard: View {
  @EnvironmentObject var viewModel: ScorigamiViewModel

  let cellSize: CGFloat
  let zoomScale: CGFloat
  let onSelect: (ScorigamiViewModel.Cell) -> Void

  var body: some View {
    let showLabels = zoomScale >= 2.2
    let scaledCell = cellSize * zoomScale
    let textSize = min(14.0, max(7.0, scaledCell * 0.35))

    VStack(spacing: 0) {
      ForEach(0...viewModel.getHighestLosingScore(), id: \.self) { losingScore in
        let row = viewModel.getGamesForLosingScore(losingScore: losingScore)
        HStack(spacing: 0) {
          ForEach(row, id: \.self) { cell in
            let colorAndSat = viewModel.getColorAndSat(cell: cell)
            ZStack {
              Rectangle()
                .foregroundColor(colorAndSat.0)
                .saturation(colorAndSat.1)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 0.5))
              if showLabels && cell.label != "" {
                Text(cell.label)
                  .font(.system(size: textSize, weight: .bold))
                  .minimumScaleFactor(0.2)
                  .lineLimit(1)
                  .foregroundColor(viewModel.getTextColor(cell: cell))
                  .padding(1)
              }
            }
            .frame(width: scaledCell, height: scaledCell)
            .contentShape(Rectangle())
            .onTapGesture {
              if cell.label != "" {
                onSelect(cell)
              }
            }
          }
        }
      }
    }
    .background(.black)
  }
}

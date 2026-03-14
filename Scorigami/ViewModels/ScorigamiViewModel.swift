//
//  ScorigamiViewModel.swift
//  Scorigami
//
//  Created by Paul Kelaita on 10/20/22.
//

import SwiftUI

class ScorigamiViewModel: ObservableObject {
  static let filteredOutRangeColor = Color(white: 0.18)
  
  var model: Scorigami
  
  var uniqueId = 0
  var colorMap: [(r: Double, g: Double, b: Double)] = []
  
  enum ColorMapType {
    case redSpecturm, fullSpectrum
  }
  @Published var colorMapType: ColorMapType = .fullSpectrum
  
  enum GradientType {
    case frequency, recency
  }
  @Published var gradientType: GradientType = .frequency
  @Published var selectedFrequencyStartCount: Int = 1
  @Published var selectedFrequencyEndCount: Int = 1
  @Published var selectedRecencyStartYear: Int = 1920
  
  @Published var zoomView: Bool = false
  @Published var resetRequestID: Int = 0
  var scrollToCell: String = ""
  
  public struct Cell: Hashable, Identifiable {
    public var id: String
    var color: Color
    var occurrences: Int
    var lastGame: String
    var gamesUrl: String
    var label: String
    var frequencySaturation: Double
    var recencySaturation: Double
    var plural: String
  }
  
  public struct GroupedGame: Hashable {
    var color: Color?
    var saturation: Double?
    var numScores: Int?
    var label: String?
    var scrollID: String?
  }
  
  private var board: [[Cell]] = []
  
  init() {
    model = ScorigamiViewModel.createScorigami()
    if isNetworkAvailable() {
      model.games.sort { $0.winningScore < $1.winningScore }
      selectedFrequencyEndCount = model.highestCounter
      selectedRecencyStartYear = model.earliestGameYear
      buildBoard()
      buildColorMap()
    }
  }
  
  static func createScorigami() -> Scorigami {
    Scorigami()
  }
  
  func isNetworkAvailable() -> Bool {
    let networkReachability = NetworkReachability()
    return networkReachability.reachable
  }
  
  func buildBoard() {
    // clear out the board and rebuild it; this is only done once at
    // initialization, but it can be called repeatedly, that's just slow
    //
    board = []
    for row in 0...getHighestWinningScore() {
      board.append([Cell]())
      for col in 0...getHighestWinningScore() {
        board[row].append(searchGames(winningScore: col, losingScore: row))
      }
    }
    uniqueId += 1
  }
  
  func searchGames(winningScore: Int, losingScore: Int) -> Cell {
    let index = model.games.firstIndex {
      $0.winningScore == winningScore &&
      $0.losingScore == losingScore }
    
    // for a particular score, build a cell for it; include a unique-id
    // which is simply the score preceded by an ever-incrementing int
    // that will ensure uniqueness across redraws
    //
    var cell = Cell(id: String(uniqueId) + ":" +
                        String(winningScore) + "-" +
                        String(losingScore),
                    color: .black,
                    occurrences: 0,
                    lastGame: "",
                    gamesUrl: "",
                    label: String(winningScore) + "-" + String(losingScore),
                    frequencySaturation: 0.0,
                    recencySaturation: 0.0,
                    plural: "s")
    
    if index != nil {
      cell.occurrences = model.games[index!].occurrences
      cell.color = Color.red
      cell.lastGame = model.games[index!].lastGame
      cell.gamesUrl = model.getParticularScoreURL(winningScore: winningScore,
                                                  losingScore: losingScore)
      cell.frequencySaturation = getSaturation(
        min: 1,
        max: model.getMaxOccorrences(),
        val: cell.occurrences,
        skewLower: 0.01,
        skewUpper: 0.55)
      cell.recencySaturation = getSaturation(
        min: model.earliestGameYear,
        max: Calendar.current.component(.year, from: Date()),
        val: getMostRecentYear(gameDesc: cell.lastGame),
        skewLower: 0.0,
        skewUpper: 1.0)
      if cell.occurrences == 1 {
        cell.plural = ""
      }
    }
    
    if winningScore < losingScore {
      cell.label = ""
    }
    return cell
  }
  
  public func getHighestWinningScore() -> Int {
    model.games.last!.winningScore
  }
  
  public func getHighestLosingScore() -> Int {
    model.highestLosingScore
  }
  
  public func getGamesForLosingScore(losingScore: Int) -> Array<Cell> {
    return board[losingScore]
  }
  
  public func getGroupedGamesForLosingScore(losingScore: Int) -> Array<GroupedGame> {
    let games: [Cell] = board[losingScore]
    var lastColor = Color.white
    var lastSaturation = 0.0
    var groupSize = 0
    var groupedGames: [GroupedGame] = []
    let maxSize = 25
    for i in 0..<games.count {
      let colorAndSat = getColorAndSat(cell: games[i])
      let color: Color = colorAndSat.0
      let saturation: Double = colorAndSat.1
      // in the first case, set as the initial "last" since there is no other
      //
      if (i == 0) {
        lastColor = color
        lastSaturation = saturation
        groupSize = 1
        continue
      }
      // else check to see if we can group these - if so, continue on;
      // maxSize is there so we don't make them too long and screw up
      // the onClick location too far
      //
      if ((color == lastColor) &&
          (saturation == lastSaturation) &&
          (groupSize <= maxSize)) {
        groupSize += 1
      } else {
        // we can't group this with previous ones (if any),
        // so write out the last one we saved
        //
        let group = GroupedGame(color: lastColor,
                                saturation: lastSaturation,
                                numScores: groupSize,
                                label: games[i].label,
                                scrollID: games[i].id)
        groupedGames.append(group)
        lastColor = color
        lastSaturation = saturation
        groupSize = 1
      }
    }
    // we're through the array, but guaranteed to have at least one game
    // left in the pipeline, so add that too
    //
    let group = GroupedGame(color: lastColor,
                            saturation: lastSaturation,
                            numScores: groupSize,
                            label: games.last?.label,
                            scrollID: games.last?.id)
    groupedGames.append(group)
    return groupedGames
  }
  
  public func getMostRecentYear(gameDesc: String) -> Int {
    let year = gameDesc.suffix(4)
    return Int(year) ?? model.earliestGameYear
  }

  public func getCurrentYear() -> Int {
    Calendar.current.component(.year, from: Date())
  }

  public func isRecencyFilterActive() -> Bool {
    gradientType == .recency && selectedRecencyStartYear > model.earliestGameYear
  }

  public func isFrequencyFilterActive() -> Bool {
    gradientType == .frequency &&
    (selectedFrequencyStartCount > 1 || selectedFrequencyEndCount < model.highestCounter)
  }

  public func updateRecencyStartYear(_ year: Int) {
    selectedRecencyStartYear = min(max(year, model.earliestGameYear), getCurrentYear())
  }

  public func updateFrequencyRange(startCount: Int, endCount: Int) {
    let clampedStart = min(max(startCount, 1), model.highestCounter)
    let clampedEnd = min(max(endCount, clampedStart), model.highestCounter)
    selectedFrequencyStartCount = clampedStart
    selectedFrequencyEndCount = clampedEnd
  }

  public func isCellWithinFrequencyRange(cell: Cell) -> Bool {
    guard cell.occurrences > 0 else { return false }
    return cell.occurrences >= selectedFrequencyStartCount &&
    cell.occurrences <= selectedFrequencyEndCount
  }

  public func isCellVisibleForCurrentFilters(cell: Cell) -> Bool {
    guard cell.label != "" else { return false }
    if gradientType == .recency && cell.occurrences > 0 {
      return getMostRecentYear(gameDesc: cell.lastGame) >= selectedRecencyStartYear
    }
    return cell.occurrences > 0
  }

  private func currentRecencySaturation(for cell: Cell) -> Double {
    let minYear = selectedRecencyStartYear
    let maxYear = getCurrentYear()
    let year = getMostRecentYear(gameDesc: cell.lastGame)
    let floor = isRecencyFilterActive() ? 0.01 : 0.0
    return getSaturation(min: minYear,
                         max: maxYear,
                         val: year,
                         skewLower: floor,
                         skewUpper: 1.0)
  }

  private func currentFrequencySaturation(for cell: Cell) -> Double {
    let minCount = selectedFrequencyStartCount
    let maxCount = selectedFrequencyEndCount
    let floor = isFrequencyFilterActive() ? 0.01 : 0.0
    return getSaturation(min: minCount,
                         max: maxCount,
                         val: cell.occurrences,
                         skewLower: floor,
                         skewUpper: 0.55)
  }
  
  public func getSaturation(min: Int,
                            max: Int,
                            val: Int,
                            skewLower: Double,
                            skewUpper: Double) -> Double {
    if max <= min {
      return val >= max ? 1.0 : 0.0
    }
    let floorSaturationPercent = skewLower
    
    // the following improves the appearance by making
    // highest intensity before the very top
    //
    let newMax = Double(max - min) * skewUpper + Double(min)
    if newMax <= Double(min) {
      return val >= max ? 1.0 : 0.0
    }
    let ratio = (Double(val) - Double(min)) /
                (newMax - Double(min))
    let saturation = (1.0 - floorSaturationPercent) *
    ratio + floorSaturationPercent
    if saturation > 1.0 {
      return 1.0
    }
    return saturation
  }
  
  public func fixScrollCell(cell: String) -> String {
    // this basically takes a score in W-L format and returns u:W-L
    // where 'u' is an increasing int that gives it uniqueness;
    // also check for invalid score where L > W
    //
    let id_scores = cell.components(separatedBy: ":")
    let id = id_scores[0]
    let scores = id_scores[1].components(separatedBy: "-")
    if Int(scores[0])! < Int(scores[1])! {
      return id + ":" + scores[1] + "-" + scores[1]
    }
    else {
      return id_scores[1]
    }
  }
  
  public func getMinMaxes() -> Array<String> {
    // used for the color map legend
    //
    if (gradientType == .frequency) {
      return [String(selectedFrequencyStartCount),
              String(selectedFrequencyEndCount)]
    }
    else {
      return [String(selectedRecencyStartYear),
              String(getCurrentYear())]
    }
  }
  
  public func buildColorMap() -> Void {
    var r: Double
    var g: Double
    var b: Double
    
    // blue to cyan
    for val in (1...25) {
      r = 0.0
      g = Double(val) * 4.0 / 100.0
      b = 1.0
      colorMap.append((r: r, g: g, b: b))
    }
    // cyan to green
    for val in (1...25) {
      r = 0.0
      g = 1.0
      b = 1.0 - (Double(val) * 4.0 / 100.0)
      colorMap.append((r: r, g: g, b: b))
    }
    // green to yellow
    for val in (1...25) {
      r = Double(val) * 4.0 / 100.0
      g = 1.0
      b = 0.0
      colorMap.append((r: r, g: g, b: b))
    }
    // yellow to red
    for val in (1...25) {
      r = 1.0
      g = 1.0 - (Double(val) * 4.0 / 100.0)
      b = 0.0
      colorMap.append((r: r, g: g, b: b))
    }
  }
  
  public func getColorAndSat(cell: Cell) -> (Color, Double) {
    // return the proper color and saturation based on gradient type,
    // full color status, and whether scorigami or not (black)
    //
    var val: Double
    
    if gradientType == .frequency {
      if !isCellWithinFrequencyRange(cell: cell) {
        return (ScorigamiViewModel.filteredOutRangeColor, 1.0)
      }
      val = currentFrequencySaturation(for: cell)
    } else {
      if !isCellVisibleForCurrentFilters(cell: cell) {
        return (ScorigamiViewModel.filteredOutRangeColor, 1.0)
      }
      val = currentRecencySaturation(for: cell)
    }
    if val == 0.0 {
      return (Color.black, 1.0)
    }
    if colorMapType == .redSpecturm {
      return (Color.red, val)
    }

    var index: Int = Int(val * 100.0)
    
    if index > 99 {
      index = 99
    }
    if index < 0 {
      index = 0
    }
    var r: Double
    var g: Double
    var b: Double
    (r, g, b) = colorMap[index]
    return (Color(red: r, green: g, blue: b), 1.0)
  }
  
  public func getTextColor(cell: Cell) -> Color {
    var val: Double
    if gradientType == .frequency {
      if !isCellWithinFrequencyRange(cell: cell) {
        return Color.white
      }
      val = currentFrequencySaturation(for: cell)
    } else {
      if !isCellVisibleForCurrentFilters(cell: cell) {
        return Color.white
      }
      val = currentRecencySaturation(for: cell)
    }
    
    if val < 0.2 || val > 0.8 ||
        colorMapType == .redSpecturm {
      return Color.white
    }
    return Color.black
  }
  
  public func changeColorMapType() {
    if colorMapType == .redSpecturm {
      colorMapType = .fullSpectrum
    } else {
      colorMapType = .redSpecturm
    }
  }
  
  public func toggleZoomView() {
    zoomView.toggle()
  }

  public func requestResetView() {
    resetRequestID += 1
  }
  
  public func setGradientType(type: Int) {
    if type == 0 {
      gradientType = .frequency
    } else {
      gradientType = .recency
    }
  }
  
}

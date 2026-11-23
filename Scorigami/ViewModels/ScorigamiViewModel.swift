//
//  ScorigamiViewModel.swift
//  Scorigami
//
//  Created by Paul Kelaita on 10/20/22.
//

import SwiftUI

class ScorigamiViewModel: ObservableObject {
  static let filteredOutRangeColor = Color(white: 0.18)
  private static let refreshInterval: TimeInterval = 24 * 60 * 60
  private static let lastPollDefaultsKey = "ScorigamiLastPollTimestamp"
  
  var model: Scorigami
  private var isRefreshingData = false
  
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
  @Published var isAutoMapEnabled = true
  @Published var autoMapRange: ClosedRange<Int>?
  
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
      markPollTimestamp()
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
                    plural: "s")
    
    if index != nil {
      cell.occurrences = model.games[index!].occurrences
      cell.color = Color.red
      cell.lastGame = model.games[index!].lastGame
      cell.gamesUrl = model.getParticularScoreURL(winningScore: winningScore,
                                                  losingScore: losingScore)
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
    !isAutoMapEnabled && gradientType == .recency && selectedRecencyStartYear > model.earliestGameYear
  }

  public func isFrequencyFilterActive() -> Bool {
    !isAutoMapEnabled && gradientType == .frequency &&
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

  private var colorRange: ClosedRange<Int>? {
    if isAutoMapEnabled { return autoMapRange }
    if gradientType == .frequency {
      return selectedFrequencyStartCount...max(selectedFrequencyStartCount, selectedFrequencyEndCount)
    }
    return selectedRecencyStartYear...max(selectedRecencyStartYear, getCurrentYear())
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
    guard let range = colorRange else { return ["-", "-"] }
    return [String(range.lowerBound), String(range.upperBound)]
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
    guard !cell.label.isEmpty, cell.occurrences > 0 else { return (.black, 1.0) }
    guard let val = colorPosition(for: cell) else { return (Self.filteredOutRangeColor, 1.0) }
    if colorMapType == .redSpecturm {
      return (Color.red, val)
    }
    if val == 0.0 {
      return (Color(red: 0, green: 0, blue: 1), 1.0)
    }
    let (r, g, b) = colorMap[min(Int(val * 100), 99)]
    return (Color(red: r, green: g, blue: b), 1.0)
  }
  
  public func getTextColor(cell: Cell) -> Color {
    guard !cell.label.isEmpty, cell.occurrences > 0,
          let val = colorPosition(for: cell) else { return .white }
    if val < 0.2 || val > 0.8 ||
        colorMapType == .redSpecturm {
      return Color.white
    }
    return Color.black
  }

  func autoMapValue(for cell: Cell) -> Int? {
    guard !cell.label.isEmpty, cell.occurrences > 0 else { return nil }
    if gradientType == .frequency { return cell.occurrences }
    return Int(cell.lastGame.suffix(4))
  }

  private func colorPosition(for cell: Cell) -> Double? {
    guard let range = colorRange else { return 0.5 }
    let value = autoMapValue(for: cell) ?? model.earliestGameYear
    if !isAutoMapEnabled && !range.contains(value) { return nil }
    if range.lowerBound == range.upperBound { return 0.5 }
    let fraction = Double(value - range.lowerBound) / Double(range.upperBound - range.lowerBound)
    return min(1, max(0, fraction))
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

  public func requestResetAndRefresh() {
    requestResetView()
    refreshDataInBackground()
  }

  public func handleAppDidBecomeActive() {
    guard !isRefreshingData else { return }
    guard shouldAutoRefreshOnForeground() else { return }
    requestResetAndRefresh()
  }

  public func refreshDataInBackground() {
    guard isNetworkAvailable() else { return }
    guard !isRefreshingData else { return }
    isRefreshingData = true

    DispatchQueue.global(qos: .userInitiated).async {
      var refreshed = ScorigamiViewModel.createScorigami()
      let didLoad = !refreshed.games.isEmpty
      if didLoad {
        refreshed.games.sort { $0.winningScore < $1.winningScore }
      }

      DispatchQueue.main.async {
        defer {
          self.markPollTimestamp()
          self.isRefreshingData = false
        }

        guard didLoad else { return }
        self.applyRefreshedModel(refreshed)
      }
    }
  }
  
  public func setGradientType(type: Int) {
    if type == 0 {
      gradientType = .frequency
    } else {
      gradientType = .recency
    }
  }

  private func applyRefreshedModel(_ refreshed: Scorigami) {
    objectWillChange.send()
    let previousHighestCounter = model.highestCounter
    let previousEarliestYear = model.earliestGameYear
    model = refreshed

    let nextFrequencyStart = min(max(selectedFrequencyStartCount, 1), model.highestCounter)
    let nextFrequencyEnd: Int
    if selectedFrequencyEndCount >= previousHighestCounter {
      nextFrequencyEnd = model.highestCounter
    } else {
      nextFrequencyEnd = min(max(selectedFrequencyEndCount, nextFrequencyStart),
                             model.highestCounter)
    }

    let nextRecencyStartYear: Int
    if selectedRecencyStartYear <= previousEarliestYear {
      nextRecencyStartYear = model.earliestGameYear
    } else {
      nextRecencyStartYear = min(max(selectedRecencyStartYear, model.earliestGameYear),
                                 getCurrentYear())
    }

    selectedFrequencyStartCount = nextFrequencyStart
    selectedFrequencyEndCount = nextFrequencyEnd
    selectedRecencyStartYear = nextRecencyStartYear
    buildBoard()
    buildColorMap()
  }

  private func markPollTimestamp(date: Date = Date()) {
    UserDefaults.standard.set(date.timeIntervalSince1970,
                              forKey: Self.lastPollDefaultsKey)
  }

  private func shouldAutoRefreshOnForeground(now: Date = Date()) -> Bool {
    let last = UserDefaults.standard.double(forKey: Self.lastPollDefaultsKey)
    guard last > 0 else { return false }
    return now.timeIntervalSince1970 - last >= Self.refreshInterval
  }
  
}

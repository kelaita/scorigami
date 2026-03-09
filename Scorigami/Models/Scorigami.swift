//
//  Scorigami.swift
//  Scorigami
//
//  Created by Paul Kelaita on 10/19/22.
//

import Foundation
import SwiftSoup

struct Scorigami {
  
  public struct Game  {
    var winningScore: Int = 0
    var losingScore: Int = 0
    var occurrences: Int = 0
    var lastGame: String = ""
  }
  
  public var highestLosingScore = 0
  public var highestCounter = 0
  public var earliestGameYear = 1920
  public var games: Array<Game>
  
  init() {
    games = Array<Game>()
    let networkReachability = NetworkReachability()
    if networkReachability.reachable {
      loadAllScores()
    }
  }
  
  static let sourceDomain = "www.pro-football-reference.com"
  
  let particularScoreURL = "https://www.pro-football-reference.com/boxscores/game_scores_find.cgi?pts_win=WWWW&pts_lose=LLLL"
  let allGamesURL = "https://kelaita.com/scores.html"
  
  public func getParticularScoreURL(winningScore: Int,
                                    losingScore: Int) -> String {
    let str = particularScoreURL.replacingOccurrences(of: "WWWW",
                                                      with: String(winningScore),
                                                      options: .literal,
                                                      range: nil)
    return str.replacingOccurrences(of: "LLLL", with: String(losingScore),
                                    options: .literal,
                                    range: nil)
  }
  
  public mutating func loadAllScores() {
    // grab the web page that has a list of all scores that have occured;
    // we will pass the raw HTML to a parsing function
    //
    let url = URL(string: allGamesURL)!
    let (data, _, _) = URLSession.shared.synchronousDataTask(with: url)
    guard let data = data else { return }
    parseAllScores(html: String(data: data, encoding: .utf8)!)
  }
  
  mutating func parseAllScores(html: String) {
    do {
      // let's use SwiftSoup to pull just the interesting table out
      // of the page; we will then use Regex to grab the info we need;
      // yes, this is klugey, but the site provides no API;
      // yes, this could break if they change their HTML formatting
      //
      let doc: Document = try SwiftSoup.parse(html)
      let rows: Array = try doc.select("tbody tr").array()
      for row in rows {
        var  game = Game()
        let lines = "\(row)".split(whereSeparator: \.isNewline)
        for line in lines {
          switch line {
          case let str where str.contains("pts_win"):
            let regex = />(\d+)<\//
            if let result = str.firstMatch(of: regex) {
              game.winningScore = Int(result.1) ?? 0
            }
          case let str where str.contains("pts_lose"):
            let regex = />(\d+)<\//
            if let result = str.firstMatch(of: regex) {
              game.losingScore = Int(result.1) ?? 0
            }
            if game.losingScore > highestLosingScore {
              highestLosingScore = game.losingScore
            }
          case let str where str.contains("counter"):
            let regex = />(\d+)<\//
            if let result = str.firstMatch(of: regex) {
              game.occurrences = Int(result.1) ?? 0
            }
            if (game.occurrences > highestCounter) {
              highestCounter = game.occurrences
            }
          case let str where str.contains("last_game"):
            let regex = /htm\">(.*?)<\//
            if let result = str.firstMatch(of: regex) {
              game.lastGame = String(result.1)
            }
          default:
            break
          }
          
          // let's change the description to clearly denote winner
          //
          if game.occurrences > 0 {
            var desc = " beat the"
            if game.winningScore == game.losingScore {
              desc = " tied the"
            }
            game.lastGame = game.lastGame.replacingOccurrences(of: " vs.",
                                                               with: desc,
                                                               options: .literal,
                                                               range: nil)
          }
        }
        games.append(game)
      }
    } catch Exception.Error(_, let message) {
      print("Message: \(message)")
    } catch {
      print("error")
    }
  }
  
  public func getMaxOccorrences() -> Int {
    games.max { $0.occurrences < $1.occurrences }!.occurrences
  }
  
}


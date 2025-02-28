//
//  InteractiveView.swift
//  Scorigami
//
//  Created by Paul Kelaita on 11/15/22.
//

import SwiftUI

struct InteractiveView: View {
  @EnvironmentObject var viewModel: ScorigamiViewModel
  @State private var currentAmount = 0.0
  @State private var finalAmount = 1.0
  
  var body: some View {
    ScrollViewReader { reader in
      ScrollView([.horizontal, .vertical], showsIndicators: false) {
        VStack {
          ForEach(0...viewModel.getHighestLosingScore(), id: \.self) { losingScore in
            LazyHGrid(rows: [GridItem(.adaptive(minimum: 20), spacing: 2)]) {
              ScoreCells(losingScore: losingScore)
            }
          }
        }.scaleEffect(finalAmount + currentAmount)
          .highPriorityGesture (
              MagnificationGesture()
                  .onChanged { amount in
                      currentAmount = amount - 1
                  }
                  .onEnded { amount in
                      finalAmount += currentAmount
                      currentAmount = 0
                  }
          )
      }
      .border(.black, width: 4)
      .preferredColorScheme(.dark)
    }
  }
}

struct ScoreCells: View {
  let losingScore: Int
  @State var showingAlert: Bool = false
  @State var score: String = ""
  @State var occurrences: Int = 0
  @State var gamesUrl: String = ""
  @State var lastGame: String = ""
  @State var plural: String = ""
  
  @EnvironmentObject var viewModel: ScorigamiViewModel
  
  var body: some View {
    // again, each row is for a losing score; unlike in full view, these
    // cells will be interactive with score labels and clickable for
    // drilldown info
    //
    let row = viewModel.getGamesForLosingScore(losingScore: losingScore)
    ForEach(row, id: \.self) { cell in
      let colorAndSat = viewModel.getColorAndSat(cell: cell)
      // we need an "id" for each cell because that is how we will
      // locate a cell and center it in the scrollview
      //
      Button(action: {
        score = cell.label
        occurrences = cell.occurrences
        gamesUrl = cell.gamesUrl
        lastGame = cell.lastGame
        plural = cell.plural
        showingAlert = true
      }) {
        Text(cell.label)
          .font(.system(size: 12)
            .weight(.bold))
          .underline(color: colorAndSat.0)
      }
      .frame(width: 40, height: 40)
      .background(colorAndSat.0)
      .saturation(colorAndSat.1)
      .foregroundColor(viewModel.getTextColor(cell: cell))
      .border(cell.color, width: 0)
      .cornerRadius(4)
      .buttonStyle(BorderlessButtonStyle())
      .id(cell.id)
      .alert("Game Score: " + score, isPresented: $showingAlert, actions: {
        if occurrences > 0 {
          Button("Done", role: .cancel, action: {})
          Link("View games", destination: URL(string: gamesUrl)!)
        }
      }, message: {
        if occurrences > 0 {
          Text("\nA game has ended with this score\n") +
          Text(String(occurrences)) +
          Text(" time") +
          Text(plural) +
          Text(".\n\nMost recently, this happened when the\n") +
          Text(lastGame)
        } else {
          Text("\nSCORIGAMI!\n\n") +
          Text("No game has ever ended\nwith this score...yet!")
        }
      })
    }
    
  }
}


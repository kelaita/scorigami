//
//  AboutView.swift
//  Scorigami
//
//  Created by Paul Kelaita on 10/30/22.
//

import SwiftUI

struct AboutView: View {
  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      HStack {
        Spacer().frame(width: 10)
        VStack {
          Text("Welcome to\n").frame(alignment: .leading)
            .font(.system(size:24))
            .frame(height: 20)
          Image("scorigami_title")
            .resizable()
            .frame(width: 300, height: 50)
          Spacer(minLength: 0).frame(height: 20)
          Text("Scorigami, a term originally coined by sportswriter Jon Bois, refers to the final score of an NFL game that has never occurred.\n").frame(maxWidth: .infinity, alignment: .leading)
          Text("This app lets you browse every score combination and see which are Scorigamis (hint: tap the black cells). For those final scores that have occurred, you can see how many games ended in that score and when it last happened.\n").frame(maxWidth: .infinity, alignment: .leading)
          Text("You can also see detailed information of every game score by tapping on each score's \"View games\" button.\n").frame(maxWidth: .infinity, alignment: .leading)
          Text("Thank you to pro-football-reference.com who provided all the historical data.\n\n\n\n").frame(maxWidth: .infinity, alignment: .leading)
          Text("This is a work-in-progress app and was created in order to learn iOS app development with SwiftUI. Would love to get some feedback at https://github.com/kelaita/scorigami").frame(maxWidth: .infinity, alignment: .leading).font(.system(size: 14))
        }.navigationBarTitle("About Scorigami")
        Spacer().frame(width: 10)
      }
      .foregroundColor(.white)
    }
  }
}

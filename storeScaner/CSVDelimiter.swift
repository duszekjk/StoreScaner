//
//  CSVDelimiter.swift
//  storeScaner
//
//  Created by Jacek Kałużny on 26/09/2025.
//


enum CSVDelimiter: String, CaseIterable {
    case comma = ","
    case semicolon = ";"

    var description: String {
        switch self {
        case .comma: return "Comma (,)"
        case .semicolon: return "Semicolon (;)"
        }
    }
}

import Foundation

struct StationMapper {

    static func displayName(from company: String?) -> String {
        guard let rawCompany = company?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawCompany.isEmpty else { return "Department" }

        let company = rawCompany
            .uppercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .joined(separator: " ")

        let compactCompany = company.replacingOccurrences(of: " ", with: "")

        switch compactCompany {
        case "FIREHQ", "FIREHEADQUARTERS", "HQ", "HEADQUARTERS":
            return "Fire Headquarters"
        case "COLLINSVILLE":
            return "Station 2"
        case "MT.KEMBLE", "MTKEMBLE":
            return "Station 1"
        case "HILLSIDE":
            return "Station 3"
        case "FAIRCHILD":
            return "Station 4"
        case "WOODLAND":
            return "Station 5"
        default:
            return company.capitalized
        }
    }

    static func stationNumber(from company: String?) -> Int? {
        switch displayName(from: company) {
        case "Station 1":
            return 1
        case "Station 2":
            return 2
        case "Station 3":
            return 3
        case "Station 4":
            return 4
        case "Station 5":
            return 5
        default:
            return nil
        }
    }
}

//
//  StationMapper.swift
//  MTFD Member App
//
//  Created by Michael Zucker on 5/3/26.
//

import Foundation

struct StationMapper {

    static func displayName(from company: String?) -> String {
        guard let rawCompany = company?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawCompany.isEmpty else { return "Station" }

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
        case "MT. KEMBLE", "MT KEMBLE":
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
}

//
//  StationMapper.swift
//  MTFD Member App
//
//  Created by Michael Zucker on 5/3/26.
//


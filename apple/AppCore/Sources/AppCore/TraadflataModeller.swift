import Foundation

// Modellene speiler det trådflata (yggdrasil/core/traadflata.ts) faktisk sender: `/api/traader`
// er `verdandi.list()` (TraadPost[]), `/api/naa` er `lagNaa()`. Bare feltene appen trenger er
// med. Ukjente felt ignoreres av Codable; bare det som identifiserer en rad er påkrevd, resten
// er valgfritt så en eldre eller nyere server ikke knekker hele svaret.

/// Hvem som holder en tråd akkurat nå (`Holder` i verdandi.ts). Fraværende holder = parkert.
public struct TraadHolder: Codable, Sendable, Equatable {
    public enum Holdertype: Sendable, Equatable {
        case terminal, plattform
        case ukjent(String)
    }

    public var type: Holdertype
    /// Harnessens egen agentstatus («idle», «working», «blocked» …), fritekst.
    public var status: String?
    public var aktiv: Bool
    public var kilde: String?

    public init(type: Holdertype, status: String? = nil, aktiv: Bool = false, kilde: String? = nil) {
        self.type = type
        self.status = status
        self.aktiv = aktiv
        self.kilde = kilde
    }
}

extension TraadHolder.Holdertype: Codable {
    public init(from decoder: Decoder) throws {
        let verdi = try decoder.singleValueContainer().decode(String.self)
        switch verdi {
        case "terminal": self = .terminal
        case "plattform": self = .plattform
        default: self = .ukjent(verdi)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .terminal: try c.encode("terminal")
        case .plattform: try c.encode("plattform")
        case .ukjent(let verdi): try c.encode(verdi)
        }
    }
}

extension TraadHolder {
    private enum CodingKeys: String, CodingKey { case type, status, aktiv, kilde }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(Holdertype.self, forKey: .type)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        aktiv = try c.decodeIfPresent(Bool.self, forKey: .aktiv) ?? false
        kilde = try c.decodeIfPresent(String.self, forKey: .kilde)
    }
}

/// Hvor tråden er tilkoblet akkurat nå (`live` i verdandi.ts). Bare `opptatt` brukes av appen.
public struct TraadLive: Codable, Sendable, Equatable {
    /// Tråden har en tur i gang akkurat nå.
    public var opptatt: Bool?

    public init(opptatt: Bool? = nil) {
        self.opptatt = opptatt
    }
}

public struct TraadProsjekt: Codable, Sendable, Equatable {
    public var id: String?
    public var jd: String?
    public var navn: String?
    public var label: String?

    public init(id: String? = nil, jd: String? = nil, navn: String? = nil, label: String? = nil) {
        self.id = id
        self.jd = jd
        self.navn = navn
        self.label = label
    }
}

/// En tråd i `/api/traader` (`TraadPost`).
public struct Traad: Codable, Sendable, Equatable, Identifiable {
    /// Det appen kan si om en tråd uten å tolke harness-detaljer.
    public enum Status: Sendable, Equatable {
        /// Tatt ut av bruk (`arkivert` er satt).
        case arkivert
        /// Noen holder tråden og holderen er aktiv.
        case holdt
        /// Ingen aktiv holder.
        case parkert
    }

    public var id: String
    public var tittel: String
    public var sistAktiv: Date
    public var holder: TraadHolder?
    public var live: TraadLive?
    public var prosjekt: TraadProsjekt?
    public var arkivert: Date?
    /// Uleverte meldinger i kø til tråden.
    public var ko: Int?

    public var status: Status {
        if arkivert != nil { return .arkivert }
        if holder?.aktiv == true { return .holdt }
        return .parkert
    }

    public init(
        id: String, tittel: String, sistAktiv: Date, holder: TraadHolder? = nil,
        prosjekt: TraadProsjekt? = nil, arkivert: Date? = nil, ko: Int? = nil, live: TraadLive? = nil
    ) {
        self.id = id
        self.tittel = tittel
        self.sistAktiv = sistAktiv
        self.holder = holder
        self.live = live
        self.prosjekt = prosjekt
        self.arkivert = arkivert
        self.ko = ko
    }

    private enum CodingKeys: String, CodingKey {
        case id, tittel, sistAktiv, holder, live, prosjekt, arkivert, ko
    }
}

/// Et kort som venter på avgjørelse (`Approval` i muninn.ts).
public struct NaaKort: Codable, Sendable, Equatable, Identifiable {
    public struct Handling: Codable, Sendable, Equatable {
        public var key: String
        public var label: String
    }

    public var id: String
    public var name: String?
    public var describe: String?
    public var status: String?
    public var expiresAt: Date?
    public var createdAt: Date?
    public var agent: String?
    public var threadKey: String?
    public var actions: [Handling]?
}

/// Noe som avviker og trenger oppmerksomhet (tjeneste nede, mission som venter, jobb med avvik).
public struct NaaAvvik: Codable, Sendable, Equatable, Identifiable {
    public var art: String
    public var navn: String
    public var tekst: String
    public var ts: Date?
    public var lenke: String?

    public var id: String { "\(art):\(navn)" }
}

public struct NaaKalenderHendelse: Codable, Sendable, Equatable {
    public var tittel: String
    public var kalender: String?
    public var ts: Date
    public var heleDagen: Bool?
}

public struct NaaPaminnelse: Codable, Sendable, Equatable {
    public var tekst: String
    public var ts: Date
}

/// `/api/naa`: det som venter på deg, og ingenting annet. Manglende lister er tomme lister.
public struct Naa: Codable, Sendable, Equatable {
    public var kort: [NaaKort]
    public var avvik: [NaaAvvik]
    public var kalender: [NaaKalenderHendelse]
    public var paminnelser: [NaaPaminnelse]
    /// Proaktive meldinger er pauset til da.
    public var pausetTil: Date?
    /// Antall jobb-baner i tidslinja.
    public var jobber: Int?

    public init(
        kort: [NaaKort] = [], avvik: [NaaAvvik] = [], kalender: [NaaKalenderHendelse] = [],
        paminnelser: [NaaPaminnelse] = [], pausetTil: Date? = nil, jobber: Int? = nil
    ) {
        self.kort = kort
        self.avvik = avvik
        self.kalender = kalender
        self.paminnelser = paminnelser
        self.pausetTil = pausetTil
        self.jobber = jobber
    }

    private enum CodingKeys: String, CodingKey {
        case kort, avvik, kalender, paminnelser, pausetTil, jobber
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kort = try c.decodeIfPresent([NaaKort].self, forKey: .kort) ?? []
        avvik = try c.decodeIfPresent([NaaAvvik].self, forKey: .avvik) ?? []
        kalender = try c.decodeIfPresent([NaaKalenderHendelse].self, forKey: .kalender) ?? []
        paminnelser = try c.decodeIfPresent([NaaPaminnelse].self, forKey: .paminnelser) ?? []
        pausetTil = try c.decodeIfPresent(Date.self, forKey: .pausetTil)
        jobber = try c.decodeIfPresent(Int.self, forKey: .jobber)
    }
}

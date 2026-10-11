import Foundation
import Testing
@testable import AppCore

@Suite struct VertTests {
    @Test(arguments: [
        ("ygg-v1.tail908368.ts.net", "ygg-v1"),
        ("YGG-V1.Tail908368.ts.net", "YGG-V1"),
        ("ygg-v1.example", "ygg-v1"),
        ("ygg-v1.example.", "ygg-v1"),
        ("a.b.c.d.e", "a"),
    ])
    func dnsNavnMedFlereLeddViserFørsteLedd(inn: String, ut: String) {
        #expect(vertVisning(inn) == ut)
    }

    @Test(arguments: ["127.0.0.1", "100.64.130.46", "192.168.1.10", "0.0.0.0", "999.1.1.1"])
    func ipv4VisesUendret(ip: String) {
        #expect(vertVisning(ip) == ip)
    }

    @Test(arguments: ["::1", "fe80::1", "2001:db8::8a2e:370:7334", "[::1]", "[::1]:3030", "[2001:db8::1]:443"])
    func ipv6VisesUendret(ip: String) {
        #expect(vertVisning(ip) == ip)
    }

    @Test(arguments: ["localhost", "ygg-v1", "draupnir", "localhost."])
    func enkeltleddVisesUendret(vert: String) {
        #expect(vertVisning(vert) == vert)
    }

    @Test func vertMedPortBeholderPorten() {
        #expect(vertVisning("ygg-v1.tail908368.ts.net:3449") == "ygg-v1:3449")
        #expect(vertVisning("localhost:3030") == "localhost:3030")
        #expect(vertVisning("127.0.0.1:3030") == "127.0.0.1:3030")
        #expect(vertVisning("ygg-v1.example:") == "ygg-v1.example:", "kolon uten port er ikke et vanlig navn")
        #expect(vertVisning("ygg-v1.example:abc") == "ygg-v1.example:abc")
    }

    @Test func tomOgUgyldigGirSpørsmålstegn() {
        #expect(vertVisning(nil) == "?")
        #expect(vertVisning("") == "?")
        #expect(vertVisning("   ") == "?")
        #expect(vertVisning("ygg v1.example") == "?")
        #expect(vertVisning("\n") == "?")
    }

    @Test func urlStiOgInnloggingVisesAldri() {
        #expect(vertVisning("https://ygg-v1.example/api?token=hemmelig") == "?")
        #expect(vertVisning("ygg-v1.example/api") == "?")
        #expect(vertVisning("bruker:hemmelig@ygg-v1.example") == "?")
        #expect(vertVisning("ygg-v1.example?token=hemmelig") == "?")
    }

    @Test func utenforVanligDnsVisesUendret() {
        #expect(vertVisning("-ygg.example") == "-ygg.example")
        #expect(vertVisning("ygg..example") == "ygg..example")
        #expect(vertVisning("ygg.ex ample") == "?")
        #expect(vertVisning("bø.example") == "bø.example", "ikke-ASCII er ikke et vanlig DNS-navn")
        #expect(vertVisning(String(repeating: "a", count: 64) + ".example") == String(repeating: "a", count: 64) + ".example")
    }

    @Test func kildeNavnBrukerVisningenOgLekkerIkkeToken() throws {
        let v = KildeValg.live(url: try #require(URL(string: "https://ygg-v1.tail908368.ts.net:3449/api")), token: "tok-hemmelig-123")
        #expect(v.navn == "live · ygg-v1")
        #expect(!v.navn.contains("hemmelig") && !v.navn.contains("/") && !v.navn.contains("3449"))
        let ip = KildeValg.live(url: try #require(URL(string: "http://127.0.0.1:3030")), token: "t")
        #expect(ip.navn == "live · 127.0.0.1")
        let ip6 = KildeValg.live(url: try #require(URL(string: "http://[::1]:3030")), token: "t")
        #expect(ip6.navn == "live · ::1")
    }
}

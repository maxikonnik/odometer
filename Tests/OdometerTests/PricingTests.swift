import Testing
@testable import OdometerCore

@Suite struct TokenCountsTests {
    @Test func totalSumsEveryBucket() {
        let counts = TokenCounts(input: 1, output: 2, cacheCreation: 3, cacheRead: 4)
        #expect(counts.total == 10)
    }

    @Test func accumulation() {
        var counts = TokenCounts(input: 1, output: 2, cacheCreation: 3, cacheRead: 4)
        counts += TokenCounts(input: 10, output: 20, cacheCreation: 30, cacheRead: 40)
        #expect(counts == TokenCounts(input: 11, output: 22, cacheCreation: 33, cacheRead: 44))
    }
}

@Suite struct PricingTests {
    @Test func exactModelIdLookup() throws {
        let price = try #require(Pricing.price(forModel: "claude-opus-5"))
        #expect(price.inputPerMTok == 5)
        #expect(price.outputPerMTok == 25)
        #expect(price.cacheWritePerMTok == 6.25)
        #expect(price.cacheReadPerMTok == 0.5)
    }

    @Test func datedSnapshotIdMatchesByPrefix() throws {
        let price = try #require(Pricing.price(forModel: "claude-haiku-4-5-20251001"))
        #expect(price.inputPerMTok == 1)
        #expect(price.outputPerMTok == 5)
    }

    @Test func fableAndSonnetRates() throws {
        let fable = try #require(Pricing.price(forModel: "claude-fable-5"))
        #expect(fable.inputPerMTok == 10)
        #expect(fable.outputPerMTok == 50)
        let sonnet = try #require(Pricing.price(forModel: "claude-sonnet-5"))
        #expect(sonnet.inputPerMTok == 3)
        #expect(sonnet.outputPerMTok == 15)
    }

    @Test func unknownModelHasNoPrice() {
        #expect(Pricing.price(forModel: "gpt-nonsense") == nil)
        #expect(Pricing.cost(of: TokenCounts(input: 1_000_000), model: "gpt-nonsense") == nil)
    }

    @Test func costAcrossAllTokenBuckets() throws {
        let counts = TokenCounts(
            input: 1_000_000,
            output: 1_000_000,
            cacheCreation: 1_000_000,
            cacheRead: 1_000_000
        )
        let cost = try #require(Pricing.cost(of: counts, model: "claude-opus-5"))
        #expect(abs(cost - (5 + 25 + 6.25 + 0.5)) < 0.0001)
    }

    @Test func costScalesBelowOneMillion() throws {
        let cost = try #require(
            Pricing.cost(of: TokenCounts(input: 500_000), model: "claude-haiku-4-5")
        )
        #expect(abs(cost - 0.5) < 0.0001)
    }
}

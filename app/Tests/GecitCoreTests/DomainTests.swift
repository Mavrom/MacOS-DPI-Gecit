import XCTest
@testable import GecitCore

let realList = """
# Engelli siteler listesi. Yalnızca buradaki siteler (ve alt alan adları)
# DPI aşma katmanından geçer; geri kalan her site normal, dokunulmadan açılır.
# Ekle:  macdpi ekle site.com     Çıkar:  macdpi cikar site.com
# Bir satıra bir alan adı. "discord.com" yazmak "*.discord.com"u da kapsar.

# Discord
discord.com
discord.gg
discord.co
discord.media
discord.dev
discord.new
discord.gift
discordapp.com
discordapp.net
discordcdn.com
discordstatus.com
dis.gd

# Roblox
roblox.com
rbxcdn.com
rbx.com

# Wattpad
wattpad.com
"""

final class DomainTests: XCTestCase {
    func testNormalizeBasics() {
        XCTAssertEqual(Domain.normalize("discord.com"), "discord.com")
        XCTAssertEqual(Domain.normalize("https://Discord.com/channels/1"), "discord.com")
        XCTAssertEqual(Domain.normalize("HTTP://www.Example.COM/a/b?c=d"), "example.com")
        XCTAssertEqual(Domain.normalize("*.roblox.com"), "roblox.com")
        XCTAssertEqual(Domain.normalize("  wattpad.com \n"), "wattpad.com")
        XCTAssertEqual(Domain.normalize("www.twitch.tv"), "twitch.tv")
        XCTAssertEqual(Domain.normalize(".discord.gg"), "discord.gg")
        XCTAssertEqual(Domain.normalize("turkiye.gov.tr"), "turkiye.gov.tr")
        XCTAssertEqual(Domain.normalize("a-b.c1.com"), "a-b.c1.com")
    }

    func testNormalizeInvalid() {
        for bad in ["a", "-x.com", "x-.com", "x..com", "ex ample.com", "", "   ", "https://", "x.com.", "çay.com", "a_b.com", "www."] {
            XCTAssertNil(Domain.normalize(bad), "\(bad) geçersiz olmalı")
        }
    }

    func testIsValid() {
        XCTAssertTrue(Domain.isValid("discord.com"))
        XCTAssertTrue(Domain.isValid("a.b"))
        XCTAssertTrue(Domain.isValid("a-b.c-d.e"))
        XCTAssertFalse(Domain.isValid("discord"))
        XCTAssertFalse(Domain.isValid("Discord.com"))
        XCTAssertFalse(Domain.isValid(".com"))
        XCTAssertFalse(Domain.isValid("a..b"))
        XCTAssertFalse(Domain.isValid("a.b-"))
    }

    func testParseListRealFile() {
        let parsed = Domain.parseList(realList)
        XCTAssertEqual(parsed, [
            "dis.gd", "discord.co", "discord.com", "discord.dev", "discord.gg", "discord.gift",
            "discord.media", "discord.new", "discordapp.com", "discordapp.net", "discordcdn.com",
            "discordstatus.com", "rbx.com", "rbxcdn.com", "roblox.com", "wattpad.com",
        ])
    }

    func testParseListShellBehaviour() {
        let text = """
        # yorum
        Discord.COM   # satır sonu yorumu
        https://Roblox.com/games
        *.wattpad.com
        .rbx.com
        www.keep.com
        discord.com
        junk
        bad..com

        """
        XCTAssertEqual(Domain.parseList(text), ["discord.com", "rbx.com", "roblox.com", "wattpad.com", "www.keep.com"])
        XCTAssertEqual(Domain.parseList(""), [])
        XCTAssertEqual(Domain.parseList("a.b\r\nc.d\r\n"), ["a.b", "c.d"])
    }
}

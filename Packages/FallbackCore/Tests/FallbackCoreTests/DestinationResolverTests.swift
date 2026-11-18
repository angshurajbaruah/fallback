import Foundation
import Testing
@testable import FallbackCore

/// One test per row of the PRD 9.5 table, using the real Resources/destinations.json.
struct DestinationResolverTests {
    let resolver: DestinationResolver = {
        let json = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../../Resources/destinations.json").standardized
        return try! DestinationResolver(json: Data(contentsOf: json))
    }()

    func web(_ url: String, title: String = "", app: String = "com.google.Chrome") -> Destination {
        resolver.resolve(url: url, title: title, appBundleID: app, appName: "Google Chrome")
    }

    @Test func workdayTenant() {
        #expect(web("https://razorpay.wd3.myworkdayjobs.com/en-US/careers/job/PM_123")
                == Destination(key: "workday:razorpay", label: "Razorpay", source: .rule))
    }

    @Test(arguments: ["https://boards.greenhouse.io/acme/jobs/42", "https://job-boards.greenhouse.io/acme/jobs/42"])
    func greenhouseCompany(url: String) {
        #expect(web(url) == Destination(key: "greenhouse:acme", label: "Acme", source: .rule))
    }

    @Test func leverCompany() {
        #expect(web("https://jobs.lever.co/emergent/1b2c3d").label == "Emergent")
    }

    @Test func ashbyCompany() {
        #expect(web("https://jobs.ashbyhq.com/notion/abc").label == "Notion")
    }

    @Test func linkedInCompanyFromTitle() {
        let found = web("https://www.linkedin.com/jobs/view/4012345", title: "Product Manager | Razorpay | LinkedIn")
        #expect(found == Destination(key: "linkedin:razorpay", label: "Razorpay", source: .rule))
    }

    @Test func naukriCompanyFromTitle() {
        let found = web("https://www.naukri.com/job-listings-pm-123", title: "Product Manager - Globex - 3 to 6 years of experience")
        #expect(found.label == "Globex")
    }

    @Test func naukriWithoutCompanyFallsBack() {
        #expect(web("https://www.naukri.com/mnjuser/homepage", title: "Home").label == "Naukri")
    }

    @Test func gmail() {
        #expect(web("https://mail.google.com/mail/u/0/#inbox?compose=new") == Destination(key: "gmail", label: "Gmail", source: .rule))
    }

    @Test(arguments: ["https://outlook.live.com/mail/0/", "https://outlook.office.com/mail/"])
    func outlook(url: String) {
        #expect(web(url).label == "Outlook")
    }

    @Test func whatsAppWeb() {
        #expect(web("https://web.whatsapp.com/").label == "WhatsApp Web")
    }

    @Test func anythingElseUsesMainDomain() {
        #expect(web("https://careers.acme.co.in/apply/pm") == Destination(key: "domain:acme.co.in", label: "acme.co.in", source: .fallback))
        #expect(web("https://www.ilovepdf.com/pdf_to_word").label == "ilovepdf.com")
    }

    // Native apps (PRD 9.5, "For native apps")

    @Test func slackChannelFromWindowTitle() {
        let found = resolver.resolve(url: nil, title: "new-channel (Channel) - testfallback - Slack",
                                     appBundleID: "com.tinyspeck.slackmacgap", appName: "Slack")
        #expect(found == Destination(key: "slack:testfallback/#new-channel", label: "#new-channel", source: .rule))
    }

    @Test func slackDirectMessage() {
        let found = resolver.resolve(url: nil, title: "Meera Iyer (DM) - acme - Slack",
                                     appBundleID: "com.tinyspeck.slackmacgap", appName: "Slack")
        #expect(found.label == "Meera Iyer")
    }

    @Test func nativeAppWithoutRuleUsesAppName() {
        let found = resolver.resolve(url: nil, title: "WhatsApp", appBundleID: "net.whatsapp.WhatsApp", appName: "WhatsApp")
        #expect(found == Destination(key: "app:net.whatsapp.WhatsApp", label: "WhatsApp", source: .fallback))
    }

    @Test func localPageUsesAppName() {
        let found = resolver.resolve(url: "file:///Users/me/upload-test.html", title: "Fallback upload test",
                                     appBundleID: "com.google.Chrome", appName: "Google Chrome")
        #expect(found.key == "app:com.google.Chrome")
    }
}

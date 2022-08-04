import XCTest
@testable import Martin

@testable import Martin
 
final class MartinTests: XCTestCase {
    func testExample() async throws {
         // This is an example of a functional test case.
         // Use XCTAssert and related functions to verify your tests produce the correct
         // results.
         //XCTAssertEqual(TigaseSwift().text, "Hello, World!")
        let client = XMPPClient();
        client.modulesManager.register(AuthModule());
        client.modulesManager.register(StreamFeaturesModule());
        client.modulesManager.register(SaslModule());
        client.modulesManager.register(ResourceBinderModule());
        client.modulesManager.register(SessionEstablishmentModule());
        client.modulesManager.register(DiscoveryModule());
        client.modulesManager.register(SoftwareVersionModule());
        client.modulesManager.register(PingModule());

        client.modulesManager.register(PresenceModule());


        client.connectionConfiguration.userJid = BareJID("home@hi-low.eu")
        client.connectionConfiguration.credentials = .password(password: "home2013", authenticationName: nil, cache: nil);

        try await client.loginAndWait();
        let iq = Iq()
        iq.to = JID("hi-low.eu")
        iq.type = .get;
        iq.element.addChild(Element(name: "query", xmlns: "http://jabber.org/protocol/disco#info"));
        let response = try await client.writer.write(iq: iq);
        print("got response: \(response)")
        let msg = Message()
        msg.to = JID("andrzej@hi-low.eu")
        msg.id = UUID().uuidString;
        msg.type = .chat;
        msg.body = "Test message \(UUID().uuidString)"
        try await client.writer.write(stanza: msg)
        try await client.disconnect();
    }

    func testExample2() async throws {
        let manager = Manager();
        for i in 1...10 {
            Task(operation: {
                usleep(100);
                let item = await manager.item(for: "test")
                print("finished!");
            })
//            Task.detached(operation: {
//                usleep(100);
//                let item = await manager.item(for: "test")
//                print("finished!");
//            })
        }
        usleep(20000);
    }
 
    static var allTests = [
        ("testExample", testExample),
    ]
}

actor Manager {

    private let store = Store();
    private var reqCounter = 0;
    private var creatingForKeys: Set<String> = [];

    public func item(for key: String) async -> Item {
        reqCounter = reqCounter + 1;
        while creatingForKeys.contains(key) {
            print("awaiting for result..");
            if let item = await store.item(for: key) {
                print("got result!")
                return item;
            }
        }
        creatingForKeys.insert(key);
        guard let item = await store.item(for: key) else {
            let item = Item(name: key);
            await store.set(item: item, for: key);
            print("created: \(reqCounter): \(item.name)")
            creatingForKeys.remove(key);
            return item;
        }
        creatingForKeys.remove(key);
        print("fetched: \(reqCounter): \(item.name)")
        return item;
    }

}

actor Store {
    
    private var items: [String: Item] = [:];

    public func set(item: Item, for key: String) {
        items[key] = item;
    }

    public func item(for key: String) -> Item? {
        usleep(150)
        return items[key];
    }

}

class Item {

    let name: String;

    init(name: String) {
        self.name = "\(name) - \(Date().timeIntervalSince1970)";
    }

}

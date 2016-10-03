import Foundation
import TigaseSwift

class MessageSendingClient: EventHandler {

    var client: XMPPClient;

    init() {
        Log.initialize();

        client = XMPPClient();

        registerModules();

        print("Notifying event bus that we are interested in SessionEstablishmentSuccessEvent" +
            " which is fired after client is connected");
        client.eventBus.register(handler: self, for: SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE);
        print("Notifying event bus that we are interested in DisconnectedEvent" +
            " which is fired after client is connected");
        client.eventBus.register(handler: self, for: SocketConnector.DisconnectedEvent.TYPE);

        setCredentials(userJID: "sender@domain.com", password: "Pa$$w0rd");

        print("Connecting to server..")
        client.login();
        print("Started async processing..");
    }

    func registerModules() {
        print("Registering modules required for authentication and session establishment");
        _ = client.modulesManager.register(AuthModule());
        _ = client.modulesManager.register(StreamFeaturesModule());
        _ = client.modulesManager.register(SaslModule());
        _ = client.modulesManager.register(ResourceBinderModule());
        _ = client.modulesManager.register(SessionEstablishmentModule());

        print("Registering module for sending/receiving messages..");
        _ = client.modulesManager.register(MessageModule());
    }

    func setCredentials(userJID: String, password: String) {
        let jid = BareJID(userJID);
        client.connectionConfiguration.setUserJID(jid);
        client.connectionConfiguration.setUserPassword(password);
    }

    /// Processing received events
    func handle(event: Event) {
        switch (event) {
        case is SessionEstablishmentModule.SessionEstablishmentSuccessEvent:
            sessionEstablished();
        case is SocketConnector.DisconnectedEvent:
            print("Client is disconnected.");
        default:
            print("unsupported event", event);
        }
    }

    /// Called when session is established
    func sessionEstablished() {
        print("Now we are connected to server and session is ready..");

        let messageModule: MessageModule = client.modulesManager.getModule(MessageModule.ID)!;
        let recipient = JID("recipient@domain.com");
        let chat = messageModule.createChat(with: recipient);
        print("Sending message to", recipient, "..");
        _ = messageModule.sendMessage(in: chat!, body: "I'm now online..");

        print("Waiting 1 sec to ensure message is sent");
        sleep(1);
        print("Disconnecting from server..");
        client.disconnect();
    }
}

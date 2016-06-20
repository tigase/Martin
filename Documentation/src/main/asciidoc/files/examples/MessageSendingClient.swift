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
        client.eventBus.register(self, events: SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE);
        print("Notifying event bus that we are interested in DisconnectedEvent" +
            " which is fired after client is connected");
        client.eventBus.register(self, events: SocketConnector.DisconnectedEvent.TYPE);

        setCredentials("sender@domain.com", password: "Pa$$w0rd");

        print("Connecting to server..")
        client.login();
        print("Started async processing..");
    }

    func registerModules() {
        print("Registering modules required for authentication and session establishment");
        client.modulesManager.register(AuthModule());
        client.modulesManager.register(StreamFeaturesModule());
        client.modulesManager.register(SaslModule());
        client.modulesManager.register(ResourceBinderModule());
        client.modulesManager.register(SessionEstablishmentModule());

        print("Registering module for sending/receiving messages..");
        client.modulesManager.register(MessageModule());
    }

    func setCredentials(userJID: String, password: String) {
        let jid = BareJID(userJID);
        client.connectionConfiguration.setUserJID(jid);
        client.connectionConfiguration.setUserPassword(password);
    }

    /// Processing received events
    func handleEvent(event: Event) {
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
        let chat = messageModule.createChat(recipient);
        print("Sending message to", recipient, "..");
        messageModule.sendMessage(chat!, body: "I'm now online..");

        print("Waiting 1 sec to ensure message is sent");
        sleep(1);
        print("Disconnecting from server..");
        client.disconnect();
    }
}

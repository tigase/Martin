import Foundation
import TigaseSwift

class MessageRespondingClient: EventHandler {
    
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
        print("Notifying event bus that we are interested in ContactPresenceChangedEvent and in MessageReceivedEvent");
        client.eventBus.register(self, events: PresenceModule.ContactPresenceChanged.TYPE, MessageModule.MessageReceivedEvent.TYPE);
        
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
        
        print("Registering module for handling presences..");
        client.modulesManager.register(PresenceModule());
        print("Registering module for handling messages..");
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
        case let cpc as PresenceModule.ContactPresenceChanged:
            contactPresenceChanged(cpc);
        case let mr as MessageModule.MessageReceivedEvent:
            messageReceived(mr);
        default:
            print("unsupported event", event);
        }
    }
    
    /// Called when session is established
    func sessionEstablished() {
        print("Now we are connected to server and session is ready..");
        
        let presenceModule: PresenceModule = client.modulesManager.getModule(PresenceModule.ID)!;
        print("Setting presence to DND...");
        presenceModule.setPresence(Presence.Show.dnd, status: "Do not distrub me!", priority: 2);
    }
    
    func contactPresenceChanged(cpc: PresenceModule.ContactPresenceChanged) {
        print("We got notified that", cpc.presence.from, "changed presence to", cpc.presence.show);
    }
    
    func messageReceived(mr: MessageModule.MessageReceivedEvent) {
        print("Received new message from", mr.message.from, "with text", mr.message.body);
        
        let messageModule: MessageModule = client.modulesManager.getModule(MessageModule.ID)!;
        print("Creating chat instance if it was not received..");
        let chat = mr.chat ?? messageModule.createChat(mr.message.from!);
        print("Sending response..");
        messageModule.sendMessage(chat!, body: "Message in response to: " + (mr.message.body ?? ""));
    }
}

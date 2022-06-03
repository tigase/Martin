import Foundation
import TigaseSwift

class MucClient: EventHandler {

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

        print("Notifying event but that we are interested in some of MucModule events");
        client.eventBus.register(handler: self, for: MucModule.YouJoinedEvent.TYPE, MucModule.MessageReceivedEvent.TYPE, MucModule.OccupantComesEvent.TYPE, MucModule.OccupantLeavedEvent.TYPE, MucModule.OccupantChangedPresenceEvent.TYPE);

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

        print("Registering module for handling presences..");
        _ = client.modulesManager.register(PresenceModule());
        print("Registering module for handling messages..");
        _ = client.modulesManager.register(MessageModule());
        print("Registering module for handling MUC...");
        _ = client.modulesManager.register(MucModule());
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
        case let cpc as PresenceModule.ContactPresenceChanged:
            contactPresenceChanged(cpc);
        case let mr as MessageModule.MessageReceivedEvent:
            messageReceived(mr);
        case let mrj as MucModule.YouJoinedEvent:
            mucRoomJoined(mrj);
        case let mmr as MucModule.MessageReceivedEvent:
            mucMessageReceived(mmr);
        case let mro as MucModule.OccupantComesEvent:
            print("Occupant", mro.occupant.nickname, "entered room with presence", mro.presence);
        case let mro as MucModule.OccupantLeavedEvent:
            print("Occupant", mro.occupant.nickname, "left room");
        case let mro as MucModule.OccupantChangedPresenceEvent:
            print("Occupant", mro.occupant.nickname, "changed presence to", mro.presence)
        default:
            print("unsupported event", event);
        }
    }

    /// Called when session is established
    func sessionEstablished() {
        print("Now we are connected to server and session is ready..");

        let presenceModule: PresenceModule = client.modulesManager.getModule(PresenceModule.ID)!;
        print("Setting presence to DND...");
        presenceModule.setPresence(show: Presence.Show.dnd, status: "Do not distrub me!", priority: 2);

        let mucModule: MucModule = client.modulesManager.getModule(MucModule.ID)!;
        _ = mucModule.join(roomName: "room-name", mucServer: "muc.domain.com", nickname: "Test");
    }

    func contactPresenceChanged(_ cpc: PresenceModule.ContactPresenceChanged) {
        print("We got notified that", cpc.presence.from, "changed presence to", cpc.presence.show);
    }

    func messageReceived(_ mr: MessageModule.MessageReceivedEvent) {
        print("Received new message from", mr.message.from, "with text", mr.message.body);

        let messageModule: MessageModule = client.modulesManager.getModule(MessageModule.ID)!;
        print("Creating chat instance if it was not received..");
        let chat = mr.chat ?? messageModule.createChat(with: mr.message.from!);
        print("Sending response..");
        _ = messageModule.sendMessage(in: chat!, body: "Message in response to: " + (mr.message.body ?? ""));
    }

    func mucRoomJoined(_ event: MucModule.YouJoinedEvent) {
        event.room.sendMessage("Welcome to all");
    }

    func mucMessageReceived(_ event: MucModule.MessageReceivedEvent) {
        print("received from", event.nickname, "message", event.message.body);
    }
}

Basics
=======

Create XMPP client instance
---------------------------------

To use TigaseSwift library you need to create instance of ``XMPPClient`` class which is implementation of XMPP client.

.. code:: swift

   var client = XMPPClient();

Register required modules
---------------------------------

Next step is to register modules providing support for features you would like to use. Almost in any case you will need at least following modules:

-  ``StreamFeaturesModule``

   Responsible for handling XMPP stream features

-  ``AuthModule`` and ``SaslModule``

   ``AuthModule`` add common authentication features, while ``SaslModule`` add support for SASL based authentication.

-  ``ResourceBinderModule``

   Module responsible for resource binding which is part of stream negotiation process.

-  ``SessionEstablishmentModule``

   Module handles session establishment which is last step of stream negotiation, however it is not needed according to `RFC 6120 <http://xmpp.org/rfcs/rfc6120.html>`__. We recommend to register this module for compatibility reasons - if it will be not needed then it will not be used.

To register, ie. ``StreamFeaturesModule`` you need to use following code:

.. code:: swift

   client.modulesManager.register(StreamFeaturesModule());

Register additional modules you need
-------------------------------------

You can add any additional modules found in TigaseSwift library or you can create your own based by implementing support for ``XmppModule`` protocol.

Here is list of some modules provided by TigaseSwift library:

-  ``PresenceModule``

   Responsible for handling incoming presences and allows to set client presence.

-  ``MessageModule``

   This module is responsible for processing incoming messages, creating/destroying chats and sending messages.

-  ``RosterModule``

   Provides support for retrieval and manipulation of XMPP roster.

-  ``MucModule``

   Provides support for MUC rooms as described in `XEP-0045: Multi-User Chat <http://xmpp.org/extensions/xep-0045.html>`__

-  ``DiscoveryModule``

   Provides support for service discovery described in `XEP-0030: Service Discovery <http://xmpp.org/extensions/xep-0030.html>`__

-  ``StreamManagementModule``

   Provides support for Stream Management acking and stream resumption as specified in `XEP-0198: Stream Management <http://xmpp.org/extensions/xep-0198.html>`__

-  ``MessageCarbonsModule``

   Adds support for forwarding messages delivered to other resources as described in `XEP-0280: Message Carbons <http://xmpp.org/extensions/xep-0280.html>`__

-  ``VCardModule``

   Implementation of support for `XEP-0054: vcard-temp <http://xmpp.org/extensions/xep-0054.html>`__

-  ``PingModule``

   Allows to check if other XMPP client is available and it is possible to deliver packet to this XMPP client as specified in `XEP-0199: XMPP Ping <http://xmpp.org/extensions/xep-0199.html>`__

-  ``InBandRegistrationModule``

   Adds possibility to register XMPP account using `XEP-0077: In-Band Registration <http://xmpp.org/extensions/xep-0077.html>`__

-  ``MobileModeModule``

   Provides support for using Tigase Optimizations for mobile devices

-  ``CapabilitiesModule``

   Provides support for `XEP-0115: Entity Capabilities <http://xmpp.org/extensions/xep-0115.html>`__ which allows for advertisement and automatic discovery of features supported by other clients.

Provide credentials needed for authentication
----------------------------------------------

This should be done using ``connectionConfiguration`` properties, ie.

.. code:: swift

   let userJID = BareJID("user@domain.com");
   client.connectionConfiguration.setUserJID(userJID);
   client.connectionConfiguration.setUserPassword("Pa$$w0rd");

To use ANONYMOUS authentication mechanism, do not set user jid and password. Instead just set server domain:

.. code:: swift

   client.connectionConfiguration.setDomain(domain);

Register for connection related events
----------------------------------------------

There are three event related to connection state which should be handled:

-  ``SocketConnector.ConnectedEvent``

   Fired when client opens TCP connection to server - XMPP stream is not ready at this point.

-  ``SessionEstablishmentModule.SessionEstablishmentSuccessEvent``

   Fired when client finishes session establishment. It will be called even if ``SessionEstablishmentModule`` is not registered.

-  ``SocketConnector.DisconnectedEvent``

   Fired when TCP connection is closed or when XMPP stream is closed. It will be also called when TCP connection is broken.

Login
---------------------------------

To start process of DNS resolution, establishing TCP connection and establishing XMPP stream you need to call:

.. code:: swift

   client.login();

Disconnect
---------------------------------

To disconnect from server properly and close XMPP and TCP connection you need to call:

.. code:: swift

   client.disconnect();

Sending custom stanza
---------------------------------

Usually class which supports ``XmppModule`` protocol is being implemented to add new feature to ``TigaseSwift`` library. However in some cases in which we want to send simple stanza or send stanza and react on received response there is no need to implement class supporting ``XmppModule`` protocol. Instead of that following methods may be used.


Sending stanza without waiting for response
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To send custom stanza you need to construct this stanza and execute following code

.. code:: swift

   client.context.writer?.write(stanza);

``writer`` is instance of ``PacketWriter`` class responsible for sending stanzas from client to server. Property can be nil if connection is not established.


Sending stanza and waiting for response (closures)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

It possible to wait for response stanza, but only in case of ``Iq`` stanzas. To do so, you need to pass callback which will be called when result will be received, ie.

.. code:: swift

   client.context.writer?.write(stanza, timeout: 45, onSuccess: {(response) in
       // response received with type equal `result`
     }, onError: {(response, errorCondition) in
       // received response with type equal `error`
     }, onTimeout: {
       // no response was received in specified time
     });

You can omit ``timeout`` parameter. Default value of 30 seconds will be used as a timeout.

You can pass nil as any of closures. In this case particular response will not trigger any reaction.


Sending stanza and waiting for response (closure)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

It possible to wait for response stanza, but only in case of ``Iq`` stanzas. To do so, you need to pass callback which will be called when result will be received, ie.

.. code:: swift

   client.context.writer?.write(stanza, timeout: 45, callback: {(response) in
     // will be called on `result`, `error` or in case of timeout
     });

You can omit ``timeout`` parameter, which will use 30 seconds as default timeout.

As callback is called always as it will be called in case of received ``result``, ``error`` or in case of timeout it is required to be able to distinguish what caused execution of this closure. In case of ``result`` or ``error`` packet being received, received stanza will be passed to closure for processing. However in case of timeout ``nil`` will be passed instead of stanza - as no stanza was received.

Sending stanza and waiting for response (AsyncCallback)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

It possible to wait for response stanza, but only in case of ``Iq`` stanzas. To do so, you need to pass callback which will be called when result will be received, ie.

.. code:: swift

   client.context.writer?.write(stanza, timeout: 45, callback: callback);

where callback is implementation of ``AsyncCallback`` protocol.

You can omit ``timeout`` parameter, which will use 30 seconds as default timeout.

Usage examples
===============

Simple client sending message
---------------------------------

Below is example code of client which send XMPP message to ``recipient@domain.com`` as ``sender@domain.com`` using ``Pa$$w0rd`` as password for authentication. Message is sent just after clients connects to server, authenticates and establishes session.

.. literalinclude:: files/examples/MessageSendingClient.swift

Simple client setting presence and handling incoming presences
--------------------------------------------------------------------

In this example we will connect to server, set our presence to ``Do not disturb`` with status message set to ``Do not disturb me!``.

This example will also print any presence we will receive from our contacts. However for this part to work our roster cannot be empty and at least one of our roster contacts needs to be available.

.. literalinclude:: files/examples/PresenceHandlingClient.swift


Simple client setting presence, handling incoming presences and responding on incoming messages
---------------------------------------------------------------------------------------------------

This example presents way to listen for incoming messages and responding on this messages.

.. literalinclude:: files/examples/MessageRespondingClient.swift


Simple client with support for MUC
------------------------------------

In this example you can find how to join to room, send message to room and handle informations about occupants.

.. literalinclude:: files/examples/MucClient.swift

Simple client with support for PubSub
------------------------------------------

In this example you can find how to create PubSub node, publish item, receive notifications, retrieve items and delete PubSub node.

.. literalinclude:: files/examples/PubSubClient.swift

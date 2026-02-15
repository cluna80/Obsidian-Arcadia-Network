"""
OAN Communication System
Enables entity-to-entity messaging
"""

from typing import Dict, List, Optional
from collections import defaultdict


class Message:
    """Represents a message between entities"""
    
    def __init__(self, sender: str, content: str, channel: Optional[str] = None, recipient: Optional[str] = None):
        self.sender = sender
        self.content = content
        self.channel = channel
        self.recipient = recipient
    
    def __repr__(self):
        if self.recipient:
            return f"[{self.sender} -> {self.recipient}] {self.content}"
        elif self.channel:
            return f"[{self.sender} @ {self.channel}] {self.content}"
        else:
            return f"[{self.sender} BROADCAST] {self.content}"


class CommunicationHub:
    """Manages all entity communication"""
    
    def __init__(self):
        self.channels: Dict[str, List[Message]] = defaultdict(list)
        self.direct_messages: Dict[str, List[Message]] = defaultdict(list)
        self.subscribers: Dict[str, List[str]] = defaultdict(list)
    
    def broadcast(self, sender_name: str, content: str):
        """Broadcast message to all entities"""
        message = Message(sender_name, content)
        self.channels['global'].append(message)
        print(f"[BROADCAST] {sender_name}: {content}")
    
    def send_to(self, sender_name: str, recipient_name: str, content: str):
        """Send direct message to specific entity"""
        message = Message(sender_name, content, recipient=recipient_name)
        self.direct_messages[recipient_name].append(message)
        print(f"[MESSAGE] {sender_name} -> {recipient_name}: {content}")
    
    def publish(self, sender_name: str, channel: str, content: str):
        """Publish message to channel"""
        message = Message(sender_name, content, channel=channel)
        self.channels[channel].append(message)
        print(f"[CHANNEL:{channel}] {sender_name}: {content}")
    
    def subscribe(self, entity_name: str, channel: str):
        """Subscribe entity to channel"""
        if entity_name not in self.subscribers[channel]:
            self.subscribers[channel].append(entity_name)
            print(f"[SUBSCRIBE] {entity_name} subscribed to {channel}")
    
    def get_messages(self, entity_name: str, channel: Optional[str] = None) -> List[Message]:
        """Get messages for an entity"""
        messages = []
        
        # Direct messages
        messages.extend(self.direct_messages.get(entity_name, []))
        
        # Channel messages if subscribed
        if channel:
            if entity_name in self.subscribers[channel]:
                messages.extend(self.channels[channel])
        else:
            # All subscribed channels
            for ch, subs in self.subscribers.items():
                if entity_name in subs:
                    messages.extend(self.channels[ch])
        
        return messages
    
    def clear_messages(self, entity_name: str):
        """Clear read messages for entity"""
        if entity_name in self.direct_messages:
            self.direct_messages[entity_name] = []


# Global communication hub
comm_hub = CommunicationHub()

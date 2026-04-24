package ws

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/geromme09/chat-system/internal/modules/chat/domain"
	notificationdomain "github.com/geromme09/chat-system/internal/modules/notification/domain"
	"github.com/gorilla/websocket"
)

const (
	websocketWriteBufferSize = 1024
	websocketReadBufferSize  = 1024
	websocketMessageType     = websocket.TextMessage
	websocketWriteTimeout    = 5 * time.Second
	websocketReadTimeout     = 60 * time.Second
	websocketPongTimeout     = 60 * time.Second
)

type ConversationLookup interface {
	GetConversation(ctx context.Context, conversationID string) (domain.Conversation, error)
	ListConversations(ctx context.Context, userID string) ([]domain.Conversation, error)
}

type Hub struct {
	logger             *slog.Logger
	conversationLookup ConversationLookup
	upgrader           websocket.Upgrader
	mu                 sync.RWMutex
	clients            map[string]map[*clientConn]struct{}
}

type clientConn struct {
	conn   *websocket.Conn
	userID string
	mu     sync.Mutex
}

type messageCreatedEnvelope struct {
	Event          string         `json:"event"`
	ConversationID string         `json:"conversation_id"`
	Message        domain.Message `json:"message"`
}

type typingEnvelope struct {
	Event          string `json:"event"`
	ConversationID string `json:"conversation_id"`
	UserID         string `json:"user_id"`
}

type presenceEnvelope struct {
	Event    string `json:"event"`
	UserID   string `json:"user_id"`
	IsOnline bool   `json:"is_online"`
}

type notificationEnvelope struct {
	Event        string                          `json:"event"`
	Notification notificationdomain.Notification `json:"notification"`
}

type conversationReadEnvelope struct {
	Event             string     `json:"event"`
	ConversationID    string     `json:"conversation_id"`
	ReaderUserID      string     `json:"reader_user_id"`
	LastReadMessageID string     `json:"last_read_message_id"`
	ReadAt            *time.Time `json:"read_at,omitempty"`
}

type inboundEnvelope struct {
	Event          string `json:"event"`
	ConversationID string `json:"conversation_id"`
}

func NewHub(logger *slog.Logger, conversationLookup ConversationLookup) *Hub {
	return &Hub{
		logger:             logger,
		conversationLookup: conversationLookup,
		upgrader: websocket.Upgrader{
			ReadBufferSize:  websocketReadBufferSize,
			WriteBufferSize: websocketWriteBufferSize,
			CheckOrigin: func(_ *http.Request) bool {
				return true
			},
		},
		clients: map[string]map[*clientConn]struct{}{},
	}
}

func (h *Hub) ServeHTTP(w http.ResponseWriter, r *http.Request, userID string) {
	conn, err := h.upgrader.Upgrade(w, r, nil)
	if err != nil {
		h.logger.Error("upgrade websocket", "error", err)
		return
	}

	client := &clientConn{
		conn:   conn,
		userID: userID,
	}
	conn.SetReadDeadline(time.Now().Add(websocketReadTimeout))
	conn.SetPongHandler(func(string) error {
		return conn.SetReadDeadline(time.Now().Add(websocketPongTimeout))
	})

	firstConnection := h.register(userID, client)
	h.sendPresenceSnapshot(userID, client)
	if firstConnection {
		h.notifyPresenceChange(userID, true)
	}

	go h.readLoop(client)
}

func (h *Hub) NotifyMessageCreated(_ context.Context, conversation domain.Conversation, message domain.Message) error {
	payload := messageCreatedEnvelope{
		Event:          domain.EventMessageCreated,
		ConversationID: conversation.ID,
		Message:        message,
	}

	encoded, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	for _, participantID := range conversation.ParticipantIDs {
		if participantID == message.SenderUserID {
			continue
		}
		h.writeToUser(participantID, encoded)
	}

	return nil
}

func (h *Hub) Deliver(_ context.Context, notification notificationdomain.Notification) error {
	encoded, err := json.Marshal(notificationEnvelope{
		Event:        notificationdomain.EventNotificationCreated,
		Notification: notification,
	})
	if err != nil {
		return err
	}

	h.writeToUser(notification.UserID, encoded)
	return nil
}

func (h *Hub) NotifyConversationRead(_ context.Context, conversation domain.Conversation, result domain.ConversationReadResult) error {
	encoded, err := json.Marshal(conversationReadEnvelope{
		Event:             domain.EventConversationRead,
		ConversationID:    conversation.ID,
		ReaderUserID:      result.ReaderUserID,
		LastReadMessageID: result.LastReadMessageID,
		ReadAt:            result.ReadAt,
	})
	if err != nil {
		return err
	}

	for _, participantID := range conversation.ParticipantIDs {
		if participantID == result.ReaderUserID {
			continue
		}
		h.writeToUser(participantID, encoded)
	}

	return nil
}

func (h *Hub) register(userID string, client *clientConn) bool {
	h.mu.Lock()
	defer h.mu.Unlock()

	connections, ok := h.clients[userID]
	if !ok {
		connections = map[*clientConn]struct{}{}
		h.clients[userID] = connections
	}
	firstConnection := len(connections) == 0
	connections[client] = struct{}{}
	return firstConnection
}

func (h *Hub) unregister(userID string, client *clientConn) bool {
	h.mu.Lock()
	defer h.mu.Unlock()

	connections, ok := h.clients[userID]
	if !ok {
		return false
	}

	delete(connections, client)
	if len(connections) > 0 {
		return false
	}

	delete(h.clients, userID)
	return true
}

func (h *Hub) readLoop(client *clientConn) {
	defer func() {
		lastConnection := h.unregister(client.userID, client)
		_ = client.conn.Close()
		if lastConnection {
			h.notifyPresenceChange(client.userID, false)
		}
	}()

	for {
		_, payload, err := client.conn.ReadMessage()
		if err != nil {
			return
		}

		h.handleInboundEvent(client, payload)
	}
}

func (h *Hub) handleInboundEvent(client *clientConn, payload []byte) {
	var incoming inboundEnvelope
	if err := json.Unmarshal(payload, &incoming); err != nil {
		return
	}
	if incoming.ConversationID == "" {
		return
	}
	if incoming.Event != domain.EventTypingStarted &&
		incoming.Event != domain.EventTypingStopped {
		return
	}

	conversation, err := h.conversationLookup.GetConversation(context.Background(), incoming.ConversationID)
	if err != nil {
		return
	}
	if !containsParticipant(conversation.ParticipantIDs, client.userID) {
		return
	}

	outbound := typingEnvelope{
		Event:          incoming.Event,
		ConversationID: incoming.ConversationID,
		UserID:         client.userID,
	}
	encoded, err := json.Marshal(outbound)
	if err != nil {
		return
	}

	for _, participantID := range conversation.ParticipantIDs {
		if participantID == client.userID {
			continue
		}
		h.writeToUser(participantID, encoded)
	}
}

func (h *Hub) sendPresenceSnapshot(userID string, client *clientConn) {
	peerIDs := h.relatedUserIDs(userID)
	for _, peerID := range peerIDs {
		payload := presenceEnvelope{
			Event:    domain.EventPresenceUpdated,
			UserID:   peerID,
			IsOnline: h.isUserOnline(peerID),
		}
		encoded, err := json.Marshal(payload)
		if err != nil {
			continue
		}
		if err := client.write(encoded); err != nil {
			h.unregister(userID, client)
			_ = client.conn.Close()
			return
		}
	}
}

func (h *Hub) notifyPresenceChange(userID string, isOnline bool) {
	peerIDs := h.relatedUserIDs(userID)
	if len(peerIDs) == 0 {
		return
	}

	encoded, err := json.Marshal(presenceEnvelope{
		Event:    domain.EventPresenceUpdated,
		UserID:   userID,
		IsOnline: isOnline,
	})
	if err != nil {
		return
	}

	for _, peerID := range peerIDs {
		h.writeToUser(peerID, encoded)
	}
}

func (h *Hub) relatedUserIDs(userID string) []string {
	conversations, err := h.conversationLookup.ListConversations(context.Background(), userID)
	if err != nil {
		return nil
	}

	peerSet := map[string]struct{}{}
	peerIDs := make([]string, 0, len(conversations))
	for _, conversation := range conversations {
		peerID := conversation.OtherParticipant.UserID
		if peerID == "" || peerID == userID {
			continue
		}
		if _, exists := peerSet[peerID]; exists {
			continue
		}
		peerSet[peerID] = struct{}{}
		peerIDs = append(peerIDs, peerID)
	}

	return peerIDs
}

func (h *Hub) isUserOnline(userID string) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()

	return len(h.clients[userID]) > 0
}

func (h *Hub) IsUserOnline(userID string) bool {
	return h.isUserOnline(userID)
}

func (h *Hub) writeToUser(userID string, payload []byte) {
	h.mu.RLock()
	connections := h.clients[userID]
	targets := make([]*clientConn, 0, len(connections))
	for client := range connections {
		targets = append(targets, client)
	}
	h.mu.RUnlock()

	for _, client := range targets {
		if err := client.write(payload); err != nil {
			lastConnection := h.unregister(userID, client)
			_ = client.conn.Close()
			if lastConnection {
				h.notifyPresenceChange(userID, false)
			}
		}
	}
}

func (c *clientConn) write(payload []byte) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if err := c.conn.SetWriteDeadline(time.Now().Add(websocketWriteTimeout)); err != nil {
		return err
	}

	return c.conn.WriteMessage(websocketMessageType, payload)
}

func containsParticipant(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}

	return false
}

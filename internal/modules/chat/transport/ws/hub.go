package ws

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/geromme09/chat-system/internal/modules/chat/domain"
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

	h.register(userID, client)
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

func (h *Hub) register(userID string, client *clientConn) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if _, ok := h.clients[userID]; !ok {
		h.clients[userID] = map[*clientConn]struct{}{}
	}
	h.clients[userID][client] = struct{}{}
}

func (h *Hub) unregister(userID string, client *clientConn) {
	h.mu.Lock()
	defer h.mu.Unlock()

	connections, ok := h.clients[userID]
	if !ok {
		return
	}

	delete(connections, client)
	if len(connections) == 0 {
		delete(h.clients, userID)
	}
}

func (h *Hub) readLoop(client *clientConn) {
	defer func() {
		h.unregister(client.userID, client)
		_ = client.conn.Close()
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
			h.unregister(userID, client)
			_ = client.conn.Close()
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

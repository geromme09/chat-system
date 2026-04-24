package integration

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	chatapp "github.com/geromme09/chat-system/internal/modules/chat/app"
	chatdomain "github.com/geromme09/chat-system/internal/modules/chat/domain"
	feedapp "github.com/geromme09/chat-system/internal/modules/feed/app"
	feeddomain "github.com/geromme09/chat-system/internal/modules/feed/domain"
	notificationdomain "github.com/geromme09/chat-system/internal/modules/notification/domain"
	userapp "github.com/geromme09/chat-system/internal/modules/user/app"
	userdomain "github.com/geromme09/chat-system/internal/modules/user/domain"
	"github.com/geromme09/chat-system/internal/platform/auth"
	"github.com/geromme09/chat-system/internal/platform/messaging"
	"github.com/geromme09/chat-system/internal/platform/storage"
)

func TestSignUpLoginAndChatFlow(t *testing.T) {
	userRepo := newUserRepositoryStub()
	chatRepo := newChatRepositoryStub()
	userService := userapp.NewService(
		userRepo,
		auth.PasswordHasher{},
		auth.NewTokenManager("test-secret"),
		storage.NewService("https://cdn.test"),
		messaging.NoopPublisher{},
		nil,
		nil,
	)
	chatService := chatapp.NewService(chatRepo, userRepo, messaging.NoopPublisher{}, nil)

	ctx := context.Background()

	alice, err := userService.SignUp(ctx, userapp.SignUpInput{
		Email:          "alice@example.com",
		Username:       "alice_one",
		Password:       "password123",
		DisplayName:    "Alice",
		AvatarFileName: "alice.png",
		City:           "Makati",
		Country:        "Philippines",
	})
	if err != nil {
		t.Fatalf("signup alice: %v", err)
	}

	bob, err := userService.SignUp(ctx, userapp.SignUpInput{
		Email:          "bob@example.com",
		Username:       "bob_two",
		Password:       "password123",
		DisplayName:    "Bob",
		AvatarFileName: "bob.png",
		City:           "Taguig",
		Country:        "Philippines",
	})
	if err != nil {
		t.Fatalf("signup bob: %v", err)
	}

	if _, err := userService.Login(ctx, userapp.LoginInput{
		Identifier: "alice_one",
		Password:   "password123",
	}); err != nil {
		t.Fatalf("login alice: %v", err)
	}

	friendRequest, err := userService.SendFriendRequest(ctx, alice.User.ID, userapp.SendFriendRequestInput{
		TargetUserID: bob.User.ID,
	})
	if err != nil {
		t.Fatalf("send friend request: %v", err)
	}

	if _, err := userService.RespondToFriendRequest(
		ctx,
		bob.User.ID,
		friendRequest.ID,
		userdomain.FriendRequestStatusAccepted,
	); err != nil {
		t.Fatalf("accept friend request: %v", err)
	}

	friends, err := userService.ListFriends(ctx, alice.User.ID, userapp.ListFriendsInput{
		Page:  1,
		Limit: 15,
	})
	if err != nil {
		t.Fatalf("list friends: %v", err)
	}

	if len(friends.Items) != 1 || friends.Items[0].UserID != bob.User.ID {
		t.Fatalf("expected bob as accepted friend, got %#v", friends)
	}

	conversation, err := chatService.CreateConversation(ctx, alice.User.ID, chatapp.CreateConversationInput{
		ParticipantIDs: []string{bob.User.ID},
	})
	if err != nil {
		t.Fatalf("create conversation: %v", err)
	}

	if _, err := chatService.SendMessage(ctx, alice.User.ID, conversation.ID, chatapp.SendMessageInput{
		Body: "tara basketball later",
	}); err != nil {
		t.Fatalf("send message: %v", err)
	}

	messages, err := chatService.ListMessages(ctx, bob.User.ID, conversation.ID)
	if err != nil {
		t.Fatalf("list messages: %v", err)
	}

	if len(messages) != 1 {
		t.Fatalf("expected 1 message, got %d", len(messages))
	}
}

func TestConversationReadReceiptsExposePeerReadState(t *testing.T) {
	userRepo := newUserRepositoryStub()
	chatRepo := newChatRepositoryStub()
	userService := userapp.NewService(
		userRepo,
		auth.PasswordHasher{},
		auth.NewTokenManager("test-secret"),
		storage.NewService("https://cdn.test"),
		messaging.NoopPublisher{},
		nil,
		nil,
	)
	chatService := chatapp.NewService(chatRepo, userRepo, messaging.NoopPublisher{}, nil)

	ctx := context.Background()

	alice, err := userService.SignUp(ctx, userapp.SignUpInput{
		Email:       "alice.receipt@example.com",
		Username:    "alice_receipt",
		Password:    "password123",
		DisplayName: "Alice Receipt",
		City:        "Makati",
	})
	if err != nil {
		t.Fatalf("signup alice: %v", err)
	}

	bob, err := userService.SignUp(ctx, userapp.SignUpInput{
		Email:       "bob.receipt@example.com",
		Username:    "bob_receipt",
		Password:    "password123",
		DisplayName: "Bob Receipt",
		City:        "Taguig",
	})
	if err != nil {
		t.Fatalf("signup bob: %v", err)
	}

	friendRequest, err := userService.SendFriendRequest(ctx, alice.User.ID, userapp.SendFriendRequestInput{
		TargetUserID: bob.User.ID,
	})
	if err != nil {
		t.Fatalf("send friend request: %v", err)
	}

	if _, err := userService.RespondToFriendRequest(
		ctx,
		bob.User.ID,
		friendRequest.ID,
		userdomain.FriendRequestStatusAccepted,
	); err != nil {
		t.Fatalf("accept friend request: %v", err)
	}

	conversation, err := chatService.CreateConversation(ctx, alice.User.ID, chatapp.CreateConversationInput{
		ParticipantIDs: []string{bob.User.ID},
	})
	if err != nil {
		t.Fatalf("create conversation: %v", err)
	}

	message, err := chatService.SendMessage(ctx, alice.User.ID, conversation.ID, chatapp.SendMessageInput{
		Body: "check receipt state",
	})
	if err != nil {
		t.Fatalf("send message: %v", err)
	}

	readResult, err := chatService.MarkConversationRead(ctx, bob.User.ID, conversation.ID)
	if err != nil {
		t.Fatalf("mark conversation read: %v", err)
	}

	if readResult.MarkedCount != 1 {
		t.Fatalf("expected 1 read message, got %d", readResult.MarkedCount)
	}
	if readResult.LastReadMessageID != message.ID {
		t.Fatalf("expected last read message %s, got %s", message.ID, readResult.LastReadMessageID)
	}

	aliceMessages, err := chatService.ListMessages(ctx, alice.User.ID, conversation.ID)
	if err != nil {
		t.Fatalf("list messages as alice: %v", err)
	}

	if len(aliceMessages) != 1 {
		t.Fatalf("expected 1 message, got %d", len(aliceMessages))
	}
	if aliceMessages[0].PeerReadAt == nil {
		t.Fatalf("expected peer read timestamp for sender view")
	}
}

func TestFeedCreateAndListFlow(t *testing.T) {
	feedRepo := newFeedRepositoryStub()
	notificationSpy := &feedNotificationServiceSpy{}
	feedService := feedapp.NewService(
		feedRepo,
		feedMediaStorageStub{},
		notificationSpy,
	)

	post, err := feedService.CreatePost(context.Background(), feeddomain.Author{
		UserID:      "user-1",
		Username:    "player_one",
		DisplayName: "Player One",
		AvatarURL:   "https://cdn.test/avatar.png",
		City:        "Makati",
	}, feedapp.CreatePostInput{
		Caption:      "Local session tonight.",
		ImageDataURL: "data:image/jpeg;base64,ZmFrZQ==",
	})
	if err != nil {
		t.Fatalf("create post: %v", err)
	}

	if post.Type != feeddomain.PostTypeImage {
		t.Fatalf("expected image post type, got %s", post.Type)
	}

	page, err := feedService.ListPosts(context.Background(), "user-1", feeddomain.ListPostsInput{
		Limit: 10,
	})
	if err != nil {
		t.Fatalf("list posts: %v", err)
	}

	if len(page.Items) != 1 {
		t.Fatalf("expected 1 post, got %d", len(page.Items))
	}
	if page.Items[0].Caption != "Local session tonight." {
		t.Fatalf("unexpected caption: %s", page.Items[0].Caption)
	}
	if page.Items[0].ImageURL != "https://cdn.test/media/feed/test-image.jpg" {
		t.Fatalf("unexpected image url: %s", page.Items[0].ImageURL)
	}

	reacted, err := feedService.ToggleReaction(context.Background(), "user-1", post.ID)
	if err != nil {
		t.Fatalf("toggle reaction: %v", err)
	}
	if !reacted.ReactedByMe || reacted.ReactionCount != 1 {
		t.Fatalf("expected reacted post with count 1, got %#v", reacted)
	}

	comment, err := feedService.CreateComment(context.Background(), feeddomain.Author{
		UserID:      "user-2",
		Username:    "player_two",
		DisplayName: "Player Two",
	}, post.ID, feedapp.CreateCommentInput{Body: "count me in"})
	if err != nil {
		t.Fatalf("create comment: %v", err)
	}
	if comment.Body != "count me in" {
		t.Fatalf("unexpected comment body: %s", comment.Body)
	}

	comments, err := feedService.ListComments(context.Background(), post.ID, 10)
	if err != nil {
		t.Fatalf("list comments: %v", err)
	}
	if len(comments) != 1 {
		t.Fatalf("expected 1 comment, got %d", len(comments))
	}

	if len(notificationSpy.notifications) != 1 {
		t.Fatalf("expected 1 notification, got %d", len(notificationSpy.notifications))
	}
	if notificationSpy.notifications[0].notificationType != notificationdomain.TypeFeedPostComment {
		t.Fatalf("expected feed post comment notification, got %s", notificationSpy.notifications[0].notificationType)
	}
}

func TestFeedReplyNotifiesParentCommentAuthor(t *testing.T) {
	feedRepo := newFeedRepositoryStub()
	notificationSpy := &feedNotificationServiceSpy{}
	feedService := feedapp.NewService(
		feedRepo,
		feedMediaStorageStub{},
		notificationSpy,
	)

	ctx := context.Background()
	post, err := feedService.CreatePost(ctx, feeddomain.Author{
		UserID:      "user-1",
		Username:    "player_one",
		DisplayName: "Player One",
	}, feedapp.CreatePostInput{
		Caption: "Open run tonight",
	})
	if err != nil {
		t.Fatalf("create post: %v", err)
	}

	firstComment, err := feedService.CreateComment(ctx, feeddomain.Author{
		UserID:      "user-2",
		Username:    "player_two",
		DisplayName: "Player Two",
	}, post.ID, feedapp.CreateCommentInput{Body: "I am in"})
	if err != nil {
		t.Fatalf("create first comment: %v", err)
	}

	_, err = feedService.CreateComment(ctx, feeddomain.Author{
		UserID:      "user-3",
		Username:    "player_three",
		DisplayName: "Player Three",
	}, post.ID, feedapp.CreateCommentInput{
		Body:            "See you there",
		ParentCommentID: firstComment.ID,
	})
	if err != nil {
		t.Fatalf("create reply: %v", err)
	}

	if len(notificationSpy.notifications) != 2 {
		t.Fatalf("expected 2 notifications, got %d", len(notificationSpy.notifications))
	}
	if notificationSpy.notifications[0].notificationType != notificationdomain.TypeFeedPostComment {
		t.Fatalf("expected first notification to be feed post comment, got %s", notificationSpy.notifications[0].notificationType)
	}
	if notificationSpy.notifications[1].notificationType != notificationdomain.TypeFeedCommentReply {
		t.Fatalf("expected second notification to be feed comment reply, got %s", notificationSpy.notifications[1].notificationType)
	}
	if notificationSpy.notifications[1].recipientUserID != "user-2" {
		t.Fatalf("expected reply recipient user-2, got %s", notificationSpy.notifications[1].recipientUserID)
	}
}

type userRepositoryStub struct {
	usersByID    map[string]userdomain.User
	usersByEmail map[string]userdomain.User
	usersByName  map[string]userdomain.User
	profiles     map[string]userdomain.Profile
	friendships  map[string]userdomain.FriendRequest
}

func newUserRepositoryStub() *userRepositoryStub {
	return &userRepositoryStub{
		usersByID:    map[string]userdomain.User{},
		usersByEmail: map[string]userdomain.User{},
		usersByName:  map[string]userdomain.User{},
		profiles:     map[string]userdomain.Profile{},
		friendships:  map[string]userdomain.FriendRequest{},
	}
}

func (r *userRepositoryStub) CreateUser(_ context.Context, user userdomain.User) error {
	if _, exists := r.usersByEmail[user.Email]; exists {
		return errors.New("email already exists")
	}
	if _, exists := r.usersByName[user.Username]; exists {
		return errors.New("username already exists")
	}

	r.usersByID[user.ID] = user
	r.usersByEmail[user.Email] = user
	r.usersByName[user.Username] = user
	return nil
}

func (r *userRepositoryStub) FindUserByEmail(_ context.Context, email string) (userdomain.User, error) {
	user, ok := r.usersByEmail[email]
	if !ok {
		return userdomain.User{}, errors.New("user not found")
	}

	return user, nil
}

func (r *userRepositoryStub) FindUserByUsername(_ context.Context, username string) (userdomain.User, error) {
	user, ok := r.usersByName[username]
	if !ok {
		return userdomain.User{}, errors.New("user not found")
	}

	return user, nil
}

func (r *userRepositoryStub) GetUser(_ context.Context, userID string) (userdomain.User, error) {
	user, ok := r.usersByID[userID]
	if !ok {
		return userdomain.User{}, errors.New("user not found")
	}

	return user, nil
}

func (r *userRepositoryStub) UpsertProfile(_ context.Context, profile userdomain.Profile) error {
	if profile.LastModified.IsZero() {
		profile.LastModified = time.Now().UTC()
	}

	r.profiles[profile.UserID] = profile
	return nil
}

func (r *userRepositoryStub) GetProfile(_ context.Context, userID string) (userdomain.Profile, error) {
	profile, ok := r.profiles[userID]
	if !ok {
		return userdomain.Profile{}, errors.New("profile not found")
	}

	return profile, nil
}

func (r *userRepositoryStub) GetPublicProfile(_ context.Context, actorUserID, targetUserID string) (userdomain.PublicProfile, error) {
	user, ok := r.usersByID[targetUserID]
	if !ok {
		return userdomain.PublicProfile{}, errors.New("profile not found")
	}
	profile, ok := r.profiles[targetUserID]
	if !ok {
		return userdomain.PublicProfile{}, errors.New("profile not found")
	}

	connectionStatus := userdomain.ConnectionStatusAdd
	if actorUserID == targetUserID {
		connectionStatus = ""
	} else {
		for _, friendship := range r.friendships {
			if (friendship.RequesterID == actorUserID && friendship.AddresseeID == targetUserID) ||
				(friendship.RequesterID == targetUserID && friendship.AddresseeID == actorUserID) {
				connectionStatus = toStubConnectionStatus(friendship.Status, friendship.RequesterID, actorUserID)
				break
			}
		}
	}

	return userdomain.PublicProfile{
		UserID:           user.ID,
		Username:         user.Username,
		DisplayName:      profile.DisplayName,
		AvatarURL:        profile.AvatarURL,
		City:             profile.City,
		Country:          profile.Country,
		Bio:              profile.Bio,
		Gender:           profile.Gender,
		HobbiesText:      profile.HobbiesText,
		Visible:          profile.Visible,
		ConnectionStatus: connectionStatus,
	}, nil
}

func (r *userRepositoryStub) SearchUsers(_ context.Context, query string, limit int, excludeUserID string) ([]userdomain.SearchResult, error) {
	results := make([]userdomain.SearchResult, 0, limit)
	for userID, profile := range r.profiles {
		if userID == excludeUserID {
			continue
		}

		user := r.usersByID[userID]
		if !strings.HasPrefix(user.Username, query) && !strings.Contains(strings.ToLower(profile.DisplayName), strings.ToLower(query)) {
			continue
		}

		results = append(results, userdomain.SearchResult{
			UserID:           user.ID,
			Username:         user.Username,
			DisplayName:      profile.DisplayName,
			AvatarURL:        profile.AvatarURL,
			City:             profile.City,
			ConnectionStatus: userdomain.ConnectionStatusAdd,
		})
		if len(results) == limit {
			break
		}
	}

	return results, nil
}

func (r *userRepositoryStub) GetFriendshipBetween(_ context.Context, userAID, userBID string) (userdomain.FriendRequest, error) {
	for _, friendship := range r.friendships {
		if (friendship.RequesterID == userAID && friendship.AddresseeID == userBID) ||
			(friendship.RequesterID == userBID && friendship.AddresseeID == userAID) {
			return friendship, nil
		}
	}

	return userdomain.FriendRequest{}, errors.New("friendship not found")
}

func (r *userRepositoryStub) CreateFriendship(_ context.Context, friendship userdomain.FriendRequest) error {
	friendship.Requester = r.userCard(friendship.RequesterID)
	friendship.Addressee = r.userCard(friendship.AddresseeID)
	r.friendships[friendship.ID] = friendship
	return nil
}

func (r *userRepositoryStub) ListIncomingFriendRequests(_ context.Context, userID string) ([]userdomain.FriendRequest, error) {
	requests := make([]userdomain.FriendRequest, 0)
	for _, friendship := range r.friendships {
		if friendship.AddresseeID == userID &&
			friendship.Status == userdomain.FriendRequestStatusPending {
			requests = append(requests, friendship)
		}
	}
	return requests, nil
}

func (r *userRepositoryStub) UpdateFriendRequestStatus(_ context.Context, requestID, addresseeUserID, status string, updatedAt time.Time) (userdomain.FriendRequest, error) {
	friendship, ok := r.friendships[requestID]
	if !ok || friendship.AddresseeID != addresseeUserID {
		return userdomain.FriendRequest{}, errors.New("friend request not found")
	}

	friendship.Status = status
	friendship.UpdatedAt = updatedAt
	friendship.SeenAt = nil
	friendship.Requester = r.userCard(friendship.RequesterID)
	friendship.Addressee = r.userCard(friendship.AddresseeID)
	r.friendships[requestID] = friendship
	return friendship, nil
}

func (r *userRepositoryStub) MarkIncomingFriendRequestsSeen(_ context.Context, userID string, seenAt time.Time) error {
	for id, friendship := range r.friendships {
		if friendship.AddresseeID == userID &&
			friendship.Status == userdomain.FriendRequestStatusPending &&
			friendship.SeenAt == nil {
			friendship.SeenAt = &seenAt
			friendship.UpdatedAt = seenAt
			r.friendships[id] = friendship
		}
	}
	return nil
}

func (r *userRepositoryStub) ListFriends(_ context.Context, userID string, offset, limit int) ([]userdomain.UserCard, error) {
	friends := make([]userdomain.UserCard, 0)
	for _, friendship := range r.friendships {
		if friendship.Status != userdomain.FriendRequestStatusAccepted {
			continue
		}
		if friendship.RequesterID == userID {
			friends = append(friends, r.userCard(friendship.AddresseeID))
		} else if friendship.AddresseeID == userID {
			friends = append(friends, r.userCard(friendship.RequesterID))
		}
	}
	if offset >= len(friends) {
		return []userdomain.UserCard{}, nil
	}

	end := offset + limit
	if end > len(friends) {
		end = len(friends)
	}

	return friends[offset:end], nil
}

func (r *userRepositoryStub) userCard(userID string) userdomain.UserCard {
	user := r.usersByID[userID]
	profile := r.profiles[userID]
	return userdomain.UserCard{
		UserID:      user.ID,
		Username:    user.Username,
		DisplayName: profile.DisplayName,
		AvatarURL:   profile.AvatarURL,
		City:        profile.City,
	}
}

type chatRepositoryStub struct {
	mu            sync.RWMutex
	conversations map[string]chatdomain.Conversation
	messages      map[string][]chatdomain.Message
	messageReads  map[string]map[string]time.Time
}

type feedRepositoryStub struct {
	mu        sync.RWMutex
	posts     []feeddomain.Post
	reactions map[string]map[string]struct{}
	comments  map[string][]feeddomain.Comment
}

type feedMediaStorageStub struct{}

type feedNotificationServiceSpy struct {
	notifications []feedNotificationCall
}

type feedNotificationCall struct {
	notificationType string
	recipientUserID  string
}

func (s *feedNotificationServiceSpy) NotifyFeedPostComment(_ context.Context, recipientUserID string, _ feeddomain.Author, _ feeddomain.Post, _ feeddomain.Comment) error {
	s.notifications = append(s.notifications, feedNotificationCall{
		notificationType: notificationdomain.TypeFeedPostComment,
		recipientUserID:  recipientUserID,
	})
	return nil
}

func (s *feedNotificationServiceSpy) NotifyFeedCommentReply(_ context.Context, recipientUserID string, _ feeddomain.Author, _ feeddomain.Post, _ feeddomain.Comment, _ feeddomain.Comment) error {
	s.notifications = append(s.notifications, feedNotificationCall{
		notificationType: notificationdomain.TypeFeedCommentReply,
		recipientUserID:  recipientUserID,
	})
	return nil
}

func (feedMediaStorageStub) SaveFeedImageDataURL(_ context.Context, dataURL string) (string, error) {
	if dataURL == "" {
		return "", errors.New("image data required")
	}

	return "https://cdn.test/media/feed/test-image.jpg", nil
}

func newFeedRepositoryStub() *feedRepositoryStub {
	return &feedRepositoryStub{
		posts:     []feeddomain.Post{},
		reactions: map[string]map[string]struct{}{},
		comments:  map[string][]feeddomain.Comment{},
	}
}

func (r *feedRepositoryStub) CreatePost(_ context.Context, post feeddomain.Post, _ string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.posts = append([]feeddomain.Post{post}, r.posts...)
	return nil
}

func (r *feedRepositoryStub) ListPosts(_ context.Context, actorUserID string, input feeddomain.ListPostsInput) ([]feeddomain.Post, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	posts := make([]feeddomain.Post, 0, len(r.posts))
	for _, post := range r.posts {
		if input.AuthorUserID != "" && post.Author.UserID != input.AuthorUserID {
			continue
		}
		posts = append(posts, post)
	}

	limit := input.Limit
	if limit <= 0 || limit > len(posts) {
		limit = len(posts)
	}

	posts = append([]feeddomain.Post{}, posts[:limit]...)
	for index := range posts {
		posts[index].ReactionCount = int64(len(r.reactions[posts[index].ID]))
		posts[index].CommentCount = int64(len(r.comments[posts[index].ID]))
		_, posts[index].ReactedByMe = r.reactions[posts[index].ID][actorUserID]
	}

	return posts, nil
}

func (r *feedRepositoryStub) GetPost(_ context.Context, actorUserID, postID string) (feeddomain.Post, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	for _, post := range r.posts {
		if post.ID == postID {
			post.ReactionCount = int64(len(r.reactions[post.ID]))
			post.CommentCount = int64(len(r.comments[post.ID]))
			_, post.ReactedByMe = r.reactions[post.ID][actorUserID]
			return post, nil
		}
	}
	return feeddomain.Post{}, errors.New("post not found")
}

func (r *feedRepositoryStub) ToggleReaction(_ context.Context, postID, userID string, _ time.Time) (feeddomain.Post, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.reactions[postID] == nil {
		r.reactions[postID] = map[string]struct{}{}
	}
	if _, exists := r.reactions[postID][userID]; exists {
		delete(r.reactions[postID], userID)
	} else {
		r.reactions[postID][userID] = struct{}{}
	}

	for _, post := range r.posts {
		if post.ID == postID {
			post.ReactionCount = int64(len(r.reactions[postID]))
			post.CommentCount = int64(len(r.comments[postID]))
			_, post.ReactedByMe = r.reactions[postID][userID]
			return post, nil
		}
	}
	return feeddomain.Post{}, errors.New("post not found")
}

func (r *feedRepositoryStub) CreateComment(_ context.Context, comment feeddomain.Comment) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.comments[comment.PostID] = append(r.comments[comment.PostID], comment)
	return nil
}

func (r *feedRepositoryStub) GetComment(_ context.Context, commentID string) (feeddomain.Comment, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	for _, comments := range r.comments {
		for _, comment := range comments {
			if comment.ID == commentID {
				return comment, nil
			}
		}
	}

	return feeddomain.Comment{}, errors.New("comment not found")
}

func (r *feedRepositoryStub) ListComments(_ context.Context, postID string, limit int) ([]feeddomain.Comment, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	comments := r.comments[postID]
	if limit > len(comments) {
		limit = len(comments)
	}
	return append([]feeddomain.Comment{}, comments[:limit]...), nil
}

func toStubConnectionStatus(friendshipStatus, requesterUserID, actorUserID string) string {
	switch friendshipStatus {
	case userdomain.FriendRequestStatusAccepted:
		return userdomain.ConnectionStatusFriends
	case userdomain.FriendRequestStatusPending:
		if requesterUserID == actorUserID {
			return userdomain.ConnectionStatusRequested
		}
		return userdomain.ConnectionStatusIncomingRequest
	default:
		return userdomain.ConnectionStatusAdd
	}
}

func newChatRepositoryStub() *chatRepositoryStub {
	return &chatRepositoryStub{
		conversations: map[string]chatdomain.Conversation{},
		messages:      map[string][]chatdomain.Message{},
		messageReads:  map[string]map[string]time.Time{},
	}
}

func (r *chatRepositoryStub) CreateConversation(_ context.Context, conversation chatdomain.Conversation) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.conversations[conversation.ID] = conversation
	return nil
}

func (r *chatRepositoryStub) FindDirectConversation(_ context.Context, userAID, userBID string) (chatdomain.Conversation, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	for _, conversation := range r.conversations {
		if len(conversation.ParticipantIDs) != 2 {
			continue
		}
		if containsParticipant(conversation.ParticipantIDs, userAID) &&
			containsParticipant(conversation.ParticipantIDs, userBID) {
			return conversation, nil
		}
	}

	return chatdomain.Conversation{}, errors.New("conversation not found")
}

func (r *chatRepositoryStub) ListConversations(_ context.Context, userID string) ([]chatdomain.Conversation, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	conversations := make([]chatdomain.Conversation, 0)
	for _, conversation := range r.conversations {
		if containsParticipant(conversation.ParticipantIDs, userID) {
			conversations = append(conversations, conversation)
		}
	}

	return conversations, nil
}

func (r *chatRepositoryStub) GetConversation(_ context.Context, conversationID string) (chatdomain.Conversation, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	conversation, ok := r.conversations[conversationID]
	if !ok {
		return chatdomain.Conversation{}, errors.New("conversation not found")
	}

	return conversation, nil
}

func (r *chatRepositoryStub) CreateMessage(_ context.Context, message chatdomain.Message) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.messages[message.ConversationID] = append(r.messages[message.ConversationID], message)
	return nil
}

func (r *chatRepositoryStub) ListMessages(_ context.Context, conversationID, userID string) ([]chatdomain.Message, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	messages := append([]chatdomain.Message{}, r.messages[conversationID]...)
	readersByMessage := r.messageReads[conversationID]
	for index, message := range messages {
		if readersByMessage == nil {
			continue
		}
		for readerID, readAt := range readersByMessage {
			if message.SenderUserID == userID && readerID != userID {
				readTime := readAt
				messages[index].PeerReadAt = &readTime
			}
			if message.SenderUserID != userID && readerID == userID {
				readTime := readAt
				messages[index].ReadAt = &readTime
			}
		}
	}

	return messages, nil
}

func (r *chatRepositoryStub) MarkConversationRead(_ context.Context, conversationID, userID string, readAt time.Time) (chatdomain.ConversationReadResult, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	var marked int64
	var lastReadMessageID string
	messages := r.messages[conversationID]
	for index, message := range messages {
		if message.SenderUserID == userID || message.ReadAt != nil {
			continue
		}
		message.ReadAt = &readAt
		messages[index] = message
		marked++
		lastReadMessageID = message.ID
	}
	r.messages[conversationID] = messages
	if marked > 0 {
		if r.messageReads[conversationID] == nil {
			r.messageReads[conversationID] = map[string]time.Time{}
		}
		r.messageReads[conversationID][userID] = readAt
	}

	result := chatdomain.ConversationReadResult{
		ConversationID:    conversationID,
		MarkedCount:       marked,
		ReaderUserID:      userID,
		LastReadMessageID: lastReadMessageID,
	}
	if marked > 0 {
		result.ReadAt = &readAt
	}

	return result, nil
}

func (r *chatRepositoryStub) GetUnreadCount(_ context.Context, userID string) (int64, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	var total int64
	for _, messages := range r.messages {
		for _, message := range messages {
			if message.SenderUserID != userID && message.ReadAt == nil {
				total++
			}
		}
	}

	return total, nil
}

func containsParticipant(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}

	return false
}

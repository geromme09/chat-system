package storage

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/geromme09/chat-system/internal/platform/identity"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

const (
	maxAvatarImageBytes = 5 * 1024 * 1024
	maxFeedImageBytes   = 8 * 1024 * 1024
	DriverLocal         = "local"
	DriverS3Compatible  = "s3"
)

type Service interface {
	SaveAvatarDataURL(ctx context.Context, userID, dataURL string) (ObjectRef, error)
	SaveFeedImageDataURL(ctx context.Context, dataURL string) (ObjectRef, error)
	PublicURL(ref ObjectRef) string
	DeleteObject(ctx context.Context, ref ObjectRef) error
}

type ObjectRef struct {
	Bucket      string
	ObjectKey   string
	ContentType string
}

type Config struct {
	BaseURL       string
	Driver        string
	LocalDir      string
	PublicBaseURL string
	S3            S3Config
}

type S3Config struct {
	Endpoint      string
	PublicBaseURL string
	AccessKeyID   string
	SecretKey     string
	UseSSL        bool
	Region        string
	ProfileBucket string
	PostBucket    string
}

type service struct {
	baseURL  string
	driver   string
	uploader objectUploader
}

type imageUpload struct {
	bytes       []byte
	contentType string
	extension   string
}

type objectUploader interface {
	Upload(ctx context.Context, bucket, key string, upload imageUpload) (ObjectRef, error)
	Delete(ctx context.Context, ref ObjectRef) error
}

func NewService(cfg Config) (Service, error) {
	driver := strings.TrimSpace(cfg.Driver)
	if driver == "" {
		driver = DriverLocal
	}

	baseURL := strings.TrimSuffix(strings.TrimSpace(cfg.BaseURL), "/")

	switch driver {
	case DriverLocal:
		return &service{
			baseURL: baseURL,
			driver:  DriverLocal,
			uploader: &localUploader{
				baseURL:  baseURL,
				localDir: normalizeLocalDir(cfg.LocalDir),
			},
		}, nil
	case DriverS3Compatible:
		s3Cfg := normalizeS3Config(cfg.S3)
		if strings.TrimSpace(cfg.PublicBaseURL) != "" {
			s3Cfg.PublicBaseURL = strings.TrimSpace(cfg.PublicBaseURL)
		}

		uploader, err := newS3Uploader(s3Cfg)
		if err != nil {
			return nil, err
		}

		if err := uploader.ensureBuckets(context.Background()); err != nil {
			return nil, err
		}

		return &service{
			baseURL:  baseURL,
			driver:   DriverS3Compatible,
			uploader: uploader,
		}, nil
	default:
		return nil, fmt.Errorf("unsupported storage driver: %s", driver)
	}
}

func (s *service) SaveAvatarDataURL(ctx context.Context, userID, dataURL string) (ObjectRef, error) {
	upload, err := parseImageDataURL(dataURL, maxAvatarImageBytes)
	if err != nil {
		return ObjectRef{}, err
	}

	key := filepath.ToSlash(filepath.Join("profiles", strings.TrimSpace(userID), "avatar", identity.NewUUID()+upload.extension))
	return s.uploader.Upload(ctx, profileBucket(s), key, upload)
}

func (s *service) SaveFeedImageDataURL(ctx context.Context, dataURL string) (ObjectRef, error) {
	upload, err := parseImageDataURL(dataURL, maxFeedImageBytes)
	if err != nil {
		return ObjectRef{}, err
	}

	key := filepath.ToSlash(filepath.Join("posts", identity.NewUUID()+upload.extension))
	return s.uploader.Upload(ctx, postBucket(s), key, upload)
}

func (s *service) PublicURL(ref ObjectRef) string {
	if ref.ObjectKey == "" {
		return ""
	}

	if ref.Bucket != "" {
		return fmt.Sprintf(
			"%s/%s/%s",
			strings.TrimSuffix(strings.TrimSpace(publicBaseURL(s.uploader)), "/"),
			ref.Bucket,
			strings.TrimLeft(ref.ObjectKey, "/"),
		)
	}

	return fmt.Sprintf("%s/media/%s", s.baseURL, strings.TrimLeft(ref.ObjectKey, "/"))
}

func (s *service) DeleteObject(ctx context.Context, ref ObjectRef) error {
	if ref.ObjectKey == "" {
		return nil
	}
	return s.uploader.Delete(ctx, ref)
}

func profileBucket(s *service) string {
	if uploader, ok := s.uploader.(*s3Uploader); ok {
		return uploader.cfg.ProfileBucket
	}
	return ""
}

func postBucket(s *service) string {
	if uploader, ok := s.uploader.(*s3Uploader); ok {
		return uploader.cfg.PostBucket
	}
	return ""
}

type localUploader struct {
	baseURL  string
	localDir string
}

func (u *localUploader) Upload(_ context.Context, _ string, key string, upload imageUpload) (ObjectRef, error) {
	targetPath := filepath.Join(u.localDir, filepath.FromSlash(key))
	if err := os.MkdirAll(filepath.Dir(targetPath), 0o755); err != nil {
		return ObjectRef{}, err
	}
	if err := os.WriteFile(targetPath, upload.bytes, 0o644); err != nil {
		return ObjectRef{}, err
	}
	return ObjectRef{
		ObjectKey:   key,
		ContentType: upload.contentType,
	}, nil
}

func (u *localUploader) Delete(_ context.Context, ref ObjectRef) error {
	targetPath := filepath.Join(u.localDir, filepath.FromSlash(ref.ObjectKey))
	if err := os.Remove(targetPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}

type s3Uploader struct {
	cfg    S3Config
	client *minio.Client
}

func newS3Uploader(cfg S3Config) (*s3Uploader, error) {
	client, err := minio.New(strings.TrimSpace(cfg.Endpoint), &minio.Options{
		Creds:  credentials.NewStaticV4(strings.TrimSpace(cfg.AccessKeyID), strings.TrimSpace(cfg.SecretKey), ""),
		Secure: cfg.UseSSL,
		Region: strings.TrimSpace(cfg.Region),
	})
	if err != nil {
		return nil, fmt.Errorf("create s3 client: %w", err)
	}

	return &s3Uploader{
		cfg:    cfg,
		client: client,
	}, nil
}

func (u *s3Uploader) Upload(ctx context.Context, bucket, key string, upload imageUpload) (ObjectRef, error) {
	_, err := u.client.PutObject(
		ctx,
		bucket,
		key,
		bytes.NewReader(upload.bytes),
		int64(len(upload.bytes)),
		minio.PutObjectOptions{
			ContentType: upload.contentType,
		},
	)
	if err != nil {
		return ObjectRef{}, fmt.Errorf("upload object: %w", err)
	}

	return ObjectRef{
		Bucket:      bucket,
		ObjectKey:   key,
		ContentType: upload.contentType,
	}, nil
}

func (u *s3Uploader) Delete(ctx context.Context, ref ObjectRef) error {
	if ref.Bucket == "" || ref.ObjectKey == "" {
		return nil
	}

	return u.client.RemoveObject(ctx, ref.Bucket, ref.ObjectKey, minio.RemoveObjectOptions{})
}

func publicBaseURL(u objectUploader) string {
	if s3, ok := u.(*s3Uploader); ok {
		return s3.cfg.PublicBaseURL
	}
	return ""
}

func (u *s3Uploader) ensureBuckets(ctx context.Context) error {
	for _, bucket := range []string{u.cfg.ProfileBucket, u.cfg.PostBucket} {
		exists, err := u.client.BucketExists(ctx, bucket)
		if err != nil {
			return fmt.Errorf("check bucket %s: %w", bucket, err)
		}
		if !exists {
			if err := u.client.MakeBucket(ctx, bucket, minio.MakeBucketOptions{
				Region: u.cfg.Region,
			}); err != nil {
				return fmt.Errorf("create bucket %s: %w", bucket, err)
			}
		}
		if err := u.setPublicReadPolicy(ctx, bucket); err != nil {
			return err
		}
	}

	return nil
}

func (u *s3Uploader) setPublicReadPolicy(ctx context.Context, bucket string) error {
	policyDocument := map[string]any{
		"Version": "2012-10-17",
		"Statement": []map[string]any{
			{
				"Effect":    "Allow",
				"Principal": map[string]any{"AWS": []string{"*"}},
				"Action":    []string{"s3:GetBucketLocation", "s3:ListBucket"},
				"Resource":  []string{fmt.Sprintf("arn:aws:s3:::%s", bucket)},
			},
			{
				"Effect":    "Allow",
				"Principal": map[string]any{"AWS": []string{"*"}},
				"Action":    []string{"s3:GetObject"},
				"Resource":  []string{fmt.Sprintf("arn:aws:s3:::%s/*", bucket)},
			},
		},
	}

	rawPolicy, err := json.Marshal(policyDocument)
	if err != nil {
		return err
	}
	if err := u.client.SetBucketPolicy(ctx, bucket, string(rawPolicy)); err != nil {
		return fmt.Errorf("set bucket policy %s: %w", bucket, err)
	}
	return nil
}

func normalizeLocalDir(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return "var/storage"
	}
	return value
}

func normalizeS3Config(cfg S3Config) S3Config {
	cfg.Endpoint = strings.TrimSpace(cfg.Endpoint)
	cfg.PublicBaseURL = strings.TrimSuffix(strings.TrimSpace(cfg.PublicBaseURL), "/")
	cfg.AccessKeyID = strings.TrimSpace(cfg.AccessKeyID)
	cfg.SecretKey = strings.TrimSpace(cfg.SecretKey)
	cfg.Region = strings.TrimSpace(cfg.Region)
	if cfg.Region == "" {
		cfg.Region = "us-east-1"
	}
	if cfg.ProfileBucket == "" {
		cfg.ProfileBucket = "profile-media"
	}
	if cfg.PostBucket == "" {
		cfg.PostBucket = "post-media"
	}
	return cfg
}

func parseImageDataURL(dataURL string, maxBytes int) (imageUpload, error) {
	mediaType, payload, ok := strings.Cut(strings.TrimSpace(dataURL), ",")
	if !ok {
		return imageUpload{}, errors.New("invalid image data URL")
	}

	mimeType := strings.TrimPrefix(mediaType, "data:")
	mimeType = strings.TrimSuffix(mimeType, ";base64")
	if !strings.HasPrefix(mimeType, "image/") || !strings.HasSuffix(mediaType, ";base64") {
		return imageUpload{}, errors.New("image_data_url must be a base64 image data URL")
	}

	decoded, err := base64.StdEncoding.DecodeString(payload)
	if err != nil {
		return imageUpload{}, errors.New("invalid image data")
	}
	if len(decoded) == 0 {
		return imageUpload{}, errors.New("image data is empty")
	}
	if len(decoded) > maxBytes {
		return imageUpload{}, errors.New("image is too large")
	}
	detectedType := http.DetectContentType(decoded)
	if !strings.HasPrefix(detectedType, "image/") {
		return imageUpload{}, errors.New("uploaded file must be a valid image")
	}

	return imageUpload{
		bytes:       decoded,
		contentType: detectedType,
		extension:   extensionForMime(detectedType),
	}, nil
}

func extensionForMime(mimeType string) string {
	if extensions, err := mime.ExtensionsByType(mimeType); err == nil && len(extensions) > 0 {
		return extensions[0]
	}

	switch mimeType {
	case "image/png":
		return ".png"
	case "image/webp":
		return ".webp"
	case "image/gif":
		return ".gif"
	default:
		return ".jpg"
	}
}

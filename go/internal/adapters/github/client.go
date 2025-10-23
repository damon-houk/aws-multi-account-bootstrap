package github

import (
	"context"
	"errors"

	"github.com/google/go-github/v67/github"
	"golang.org/x/oauth2"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// Client implements the ports.GitHubClient interface using go-github SDK.
//
// This adapter connects the domain logic to real GitHub API services.
// For testing without GitHub credentials, use the mock adapter instead.
type Client struct {
	client *github.Client
	token  string
}

// NewClient creates a new GitHub client with token authentication.
//
// The token should be a GitHub Personal Access Token or GitHub App token
// with appropriate permissions:
// - repo (full control of private repositories)
// - workflow (update GitHub Actions workflows)
// - admin:org (full control of organizations)
//
// Returns an error if the token is empty.
func NewClient(ctx context.Context, token string) (*Client, error) {
	if token == "" {
		return nil, errors.New("GitHub token is required")
	}

	// Create OAuth2 token source
	ts := oauth2.StaticTokenSource(
		&oauth2.Token{AccessToken: token},
	)
	tc := oauth2.NewClient(ctx, ts)

	// Create GitHub client
	ghClient := github.NewClient(tc)

	return &Client{
		client: ghClient,
		token:  token,
	}, nil
}

// NewClientWithGitHub creates a GitHub client with a pre-configured go-github client.
//
// This is useful for testing or when you want to customize the HTTP client.
func NewClientWithGitHub(ghClient *github.Client, token string) *Client {
	return &Client{
		client: ghClient,
		token:  token,
	}
}

// Compile-time check to ensure Client implements ports.GitHubClient
var _ ports.GitHubClient = (*Client)(nil)

// Name returns "GitHub" for logging and debugging.
func (c *Client) Name() string {
	return "GitHub"
}

// GetCurrentUser returns the authenticated user's username.
func (c *Client) GetCurrentUser(ctx context.Context) (string, error) {
	user, _, err := c.client.Users.Get(ctx, "")
	if err != nil {
		return "", err
	}

	if user.Login == nil {
		return "", errors.New("user login is nil")
	}

	return *user.Login, nil
}

// IsAuthenticated checks if the client is authenticated with GitHub.
func (c *Client) IsAuthenticated(ctx context.Context) (bool, error) {
	_, _, err := c.client.Users.Get(ctx, "")
	if err != nil {
		return false, err
	}
	return true, nil
}
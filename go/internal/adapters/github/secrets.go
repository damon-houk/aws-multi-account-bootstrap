package github

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"

	"github.com/google/go-github/v67/github"
	"golang.org/x/crypto/nacl/box"
)

// SetRepositorySecret sets a repository-level secret.
//
// The secret value is encrypted before being sent to GitHub.
// This is idempotent - calling multiple times updates the secret.
func (c *Client) SetRepositorySecret(ctx context.Context, org, repo, name, value string) error {
	if org == "" || repo == "" {
		return errors.New("org and repo are required")
	}
	if name == "" {
		return errors.New("secret name is required")
	}
	if value == "" {
		return errors.New("secret value is required")
	}

	// Get the public key for encryption
	publicKey, _, err := c.client.Actions.GetRepoPublicKey(ctx, org, repo)
	if err != nil {
		return fmt.Errorf("failed to get repository public key: %w", err)
	}

	// Encrypt the secret value
	encryptedValue, err := encryptSecret(publicKey, value)
	if err != nil {
		return fmt.Errorf("failed to encrypt secret: %w", err)
	}

	// Create or update the secret
	secret := &github.EncryptedSecret{
		Name:           name,
		KeyID:          publicKey.GetKeyID(),
		EncryptedValue: encryptedValue,
	}

	_, err = c.client.Actions.CreateOrUpdateRepoSecret(ctx, org, repo, secret)
	if err != nil {
		return fmt.Errorf("failed to create/update repository secret: %w", err)
	}

	return nil
}

// SetRepositoryVariable sets a repository-level variable (non-secret).
//
// Variables are not encrypted and are visible in the GitHub UI.
// This is idempotent - calling multiple times updates the variable.
func (c *Client) SetRepositoryVariable(ctx context.Context, org, repo, name, value string) error {
	if org == "" || repo == "" {
		return errors.New("org and repo are required")
	}
	if name == "" {
		return errors.New("variable name is required")
	}

	// Create or update the variable
	variable := &github.ActionsVariable{
		Name:  name,
		Value: value,
	}

	_, err := c.client.Actions.CreateRepoVariable(ctx, org, repo, variable)
	if err != nil {
		// Try updating if creation failed (variable might exist)
		_, err = c.client.Actions.UpdateRepoVariable(ctx, org, repo, variable)
		if err != nil {
			return fmt.Errorf("failed to create/update repository variable: %w", err)
		}
	}

	return nil
}

// SetEnvironmentSecret sets an environment-level secret.
//
// The secret value is encrypted before being sent to GitHub.
// This is idempotent - calling multiple times updates the secret.
func (c *Client) SetEnvironmentSecret(ctx context.Context, org, repo, environment, name, value string) error {
	if org == "" || repo == "" {
		return errors.New("org and repo are required")
	}
	if environment == "" {
		return errors.New("environment is required")
	}
	if name == "" {
		return errors.New("secret name is required")
	}
	if value == "" {
		return errors.New("secret value is required")
	}

	// Get repository ID (needed for environment operations)
	repository, _, err := c.client.Repositories.Get(ctx, org, repo)
	if err != nil {
		return fmt.Errorf("failed to get repository: %w", err)
	}

	// Get the public key for the environment
	repoID := int(repository.GetID())
	publicKey, _, err := c.client.Actions.GetEnvPublicKey(ctx, repoID, environment)
	if err != nil {
		return fmt.Errorf("failed to get environment public key: %w", err)
	}

	// Encrypt the secret value
	encryptedValue, err := encryptSecret(publicKey, value)
	if err != nil {
		return fmt.Errorf("failed to encrypt secret: %w", err)
	}

	// Create or update the environment secret
	secret := &github.EncryptedSecret{
		Name:           name,
		KeyID:          publicKey.GetKeyID(),
		EncryptedValue: encryptedValue,
	}

	_, err = c.client.Actions.CreateOrUpdateEnvSecret(ctx, repoID, environment, secret)
	if err != nil {
		return fmt.Errorf("failed to create/update environment secret: %w", err)
	}

	return nil
}

// encryptSecret encrypts a secret value using GitHub's public key.
//
// GitHub uses NaCl box (libsodium) for encrypting secrets.
func encryptSecret(publicKey *github.PublicKey, secretValue string) (string, error) {
	// Decode the public key from base64
	decodedPublicKey, err := base64.StdEncoding.DecodeString(publicKey.GetKey())
	if err != nil {
		return "", fmt.Errorf("failed to decode public key: %w", err)
	}

	// Convert to [32]byte for NaCl
	var boxKey [32]byte
	copy(boxKey[:], decodedPublicKey)

	// Encrypt the secret using anonymous encryption (sealed box)
	encrypted, err := box.SealAnonymous(nil, []byte(secretValue), &boxKey, rand.Reader)
	if err != nil {
		return "", fmt.Errorf("failed to encrypt: %w", err)
	}

	// Encode to base64
	return base64.StdEncoding.EncodeToString(encrypted), nil
}
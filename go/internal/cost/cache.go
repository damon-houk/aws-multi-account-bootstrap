package cost

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// FilePriceCache implements file-based caching for pricing data
type FilePriceCache struct {
	cacheDir string
	ttl      time.Duration
}

// NewFilePriceCache creates a new file-based cache
// Default location: ~/.aws-bootstrap/pricing-cache/
// Default TTL: 7 days
func NewFilePriceCache() (*FilePriceCache, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("failed to get home directory: %w", err)
	}

	cacheDir := filepath.Join(homeDir, ".aws-bootstrap", "pricing-cache")
	if err := os.MkdirAll(cacheDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create cache directory: %w", err)
	}

	return &FilePriceCache{
		cacheDir: cacheDir,
		ttl:      7 * 24 * time.Hour, // 7 days
	}, nil
}

// NewFilePriceCacheWithTTL creates a cache with custom TTL
func NewFilePriceCacheWithTTL(ttl time.Duration) (*FilePriceCache, error) {
	cache, err := NewFilePriceCache()
	if err != nil {
		return nil, err
	}
	cache.ttl = ttl
	return cache, nil
}

// Get retrieves a cached price result
func (c *FilePriceCache) Get(query PriceQuery) (PriceResult, bool) {
	cacheKey := c.getCacheKey(query)
	cachePath := filepath.Join(c.cacheDir, cacheKey+".json")

	// Check if file exists
	info, err := os.Stat(cachePath)
	if os.IsNotExist(err) {
		return PriceResult{}, false
	}

	// Check if cache is expired
	if time.Since(info.ModTime()) > c.ttl {
		// Expired, remove file
		os.Remove(cachePath)
		return PriceResult{}, false
	}

	// Read cache file
	data, err := os.ReadFile(cachePath)
	if err != nil {
		return PriceResult{}, false
	}

	// Parse cached result
	var result PriceResult
	if err := json.Unmarshal(data, &result); err != nil {
		return PriceResult{}, false
	}

	// Mark as from cache
	result.FromCache = true

	return result, true
}

// Set stores a price result in cache
func (c *FilePriceCache) Set(query PriceQuery, result PriceResult) {
	cacheKey := c.getCacheKey(query)
	cachePath := filepath.Join(c.cacheDir, cacheKey+".json")

	// Serialize result
	data, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		// Silently fail - caching is optional
		return
	}

	// Write to file
	if err := os.WriteFile(cachePath, data, 0644); err != nil {
		// Silently fail - caching is optional
		return
	}
}

// Clear removes all cached entries
func (c *FilePriceCache) Clear() error {
	entries, err := os.ReadDir(c.cacheDir)
	if err != nil {
		return fmt.Errorf("failed to read cache directory: %w", err)
	}

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		path := filepath.Join(c.cacheDir, entry.Name())
		if err := os.Remove(path); err != nil {
			return fmt.Errorf("failed to remove cache file %s: %w", entry.Name(), err)
		}
	}

	return nil
}

// ClearExpired removes only expired cache entries
func (c *FilePriceCache) ClearExpired() error {
	entries, err := os.ReadDir(c.cacheDir)
	if err != nil {
		return fmt.Errorf("failed to read cache directory: %w", err)
	}

	now := time.Now()
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		path := filepath.Join(c.cacheDir, entry.Name())
		info, err := entry.Info()
		if err != nil {
			continue
		}

		// Remove if expired
		if now.Sub(info.ModTime()) > c.ttl {
			os.Remove(path)
		}
	}

	return nil
}

// getCacheKey generates a cache key from a query
func (c *FilePriceCache) getCacheKey(query PriceQuery) string {
	// Create a deterministic string representation
	key := fmt.Sprintf("%s|%s|%s", query.Service, query.ProductFamily, query.Region)

	// Add sorted attributes
	for k, v := range query.Attributes {
		key += fmt.Sprintf("|%s=%s", k, v)
	}

	// Hash to create filename-safe key
	hash := sha256.Sum256([]byte(key))
	return fmt.Sprintf("%x", hash)
}

// GetStats returns cache statistics
func (c *FilePriceCache) GetStats() (total int, size int64, err error) {
	entries, err := os.ReadDir(c.cacheDir)
	if err != nil {
		return 0, 0, fmt.Errorf("failed to read cache directory: %w", err)
	}

	total = 0
	size = 0

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		info, err := entry.Info()
		if err != nil {
			continue
		}

		total++
		size += info.Size()
	}

	return total, size, nil
}
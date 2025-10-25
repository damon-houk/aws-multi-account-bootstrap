package cost

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// HTTPPricingClient fetches pricing data from AWS Pricing API via HTTP
type HTTPPricingClient struct {
	baseURL    string
	httpClient *http.Client
	cache      PriceCache
}

// NewHTTPPricingClient creates a new HTTP-based pricing client
func NewHTTPPricingClient(cache PriceCache) *HTTPPricingClient {
	return &HTTPPricingClient{
		baseURL: "https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws",
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		cache: cache,
	}
}

// GetPrice fetches price for a single query
func (c *HTTPPricingClient) GetPrice(query PriceQuery) (PriceResult, error) {
	// Check cache first
	if c.cache != nil {
		if cached, found := c.cache.Get(query); found {
			return cached, nil
		}
	}

	// Fetch from API
	result, err := c.fetchPrice(query)
	if err != nil {
		return PriceResult{}, err
	}

	// Store in cache
	if c.cache != nil {
		c.cache.Set(query, result)
	}

	return result, nil
}

// GetPrices fetches multiple prices (batch operation)
func (c *HTTPPricingClient) GetPrices(queries []PriceQuery) ([]PriceResult, error) {
	results := make([]PriceResult, 0, len(queries))

	for _, query := range queries {
		result, err := c.GetPrice(query)
		if err != nil {
			// Continue on error, collect results for successful queries
			continue
		}
		results = append(results, result)
	}

	if len(results) == 0 {
		return nil, fmt.Errorf("no prices could be fetched")
	}

	return results, nil
}

// fetchPrice fetches price from AWS Pricing API
func (c *HTTPPricingClient) fetchPrice(query PriceQuery) (PriceResult, error) {
	// Build API URL
	// Format: /offers/v1.0/aws/{ServiceCode}/current/index.json
	serviceCode := query.Service
	apiURL := fmt.Sprintf("%s/%s/current/index.json", c.baseURL, serviceCode)

	// Fetch the pricing data
	resp, err := c.httpClient.Get(apiURL)
	if err != nil {
		return PriceResult{}, fmt.Errorf("failed to fetch pricing: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return PriceResult{}, fmt.Errorf("pricing API returned status %d", resp.StatusCode)
	}

	// Parse response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return PriceResult{}, fmt.Errorf("failed to read response: %w", err)
	}

	var priceData AWSPricingResponse
	if err := json.Unmarshal(body, &priceData); err != nil {
		return PriceResult{}, fmt.Errorf("failed to parse pricing data: %w", err)
	}

	// Find matching product
	matchedSKU, _ := c.findMatchingProduct(priceData.Products, query)
	if matchedSKU == "" {
		return PriceResult{}, fmt.Errorf("no matching product found for query: %+v", query)
	}

	// Get price from terms
	unitPrice, unit, err := c.extractPrice(priceData.Terms.OnDemand, matchedSKU)
	if err != nil {
		return PriceResult{}, fmt.Errorf("failed to extract price: %w", err)
	}

	return PriceResult{
		Query:     query,
		SKU:       matchedSKU,
		UnitPrice: unitPrice,
		Unit:      unit,
		Currency:  "USD",
		FetchedAt: time.Now(),
		FromCache: false,
	}, nil
}

// findMatchingProduct finds a product that matches the query filters
func (c *HTTPPricingClient) findMatchingProduct(products map[string]Product, query PriceQuery) (string, Product) {
	for sku, product := range products {
		// Check product family
		if query.ProductFamily != "" && product.Attributes["productFamily"] != query.ProductFamily {
			continue
		}

		// Check region
		if query.Region != "" {
			regionName := c.regionCodeToName(query.Region)
			if product.Attributes["location"] != regionName && product.Attributes["regionCode"] != query.Region {
				continue
			}
		}

		// Check all additional attributes
		matches := true
		for key, value := range query.Attributes {
			if product.Attributes[key] != value {
				matches = false
				break
			}
		}

		if matches {
			return sku, product
		}
	}

	return "", Product{}
}

// extractPrice extracts the unit price from OnDemand terms
func (c *HTTPPricingClient) extractPrice(onDemandTerms map[string]map[string]OnDemandTerm, sku string) (float64, string, error) {
	// Navigate: terms.OnDemand[SKU][offerTermCode].priceDimensions[dimensionKey].pricePerUnit.USD
	skuTerms, found := onDemandTerms[sku]
	if !found {
		return 0, "", fmt.Errorf("no on-demand terms for SKU %s", sku)
	}

	// Get first offer term (usually only one)
	for _, term := range skuTerms {
		// Get first price dimension
		for _, dimension := range term.PriceDimensions {
			// Parse price
			if priceStr, ok := dimension.PricePerUnit["USD"]; ok {
				var price float64
				if _, err := fmt.Sscanf(priceStr, "%f", &price); err != nil {
					return 0, "", fmt.Errorf("failed to parse price: %w", err)
				}
				return price, dimension.Unit, nil
			}
		}
	}

	return 0, "", fmt.Errorf("no price found in terms")
}

// regionCodeToName converts region code to location name used by pricing API
func (c *HTTPPricingClient) regionCodeToName(regionCode string) string {
	// AWS Pricing API uses location names instead of region codes
	regionMap := map[string]string{
		"us-east-1":      "US East (N. Virginia)",
		"us-east-2":      "US East (Ohio)",
		"us-west-1":      "US West (N. California)",
		"us-west-2":      "US West (Oregon)",
		"eu-west-1":      "EU (Ireland)",
		"eu-west-2":      "EU (London)",
		"eu-central-1":   "EU (Frankfurt)",
		"ap-southeast-1": "Asia Pacific (Singapore)",
		"ap-southeast-2": "Asia Pacific (Sydney)",
		"ap-northeast-1": "Asia Pacific (Tokyo)",
	}

	if name, found := regionMap[regionCode]; found {
		return name
	}
	return regionCode
}

// AWSPricingResponse represents the structure of AWS Pricing API response
type AWSPricingResponse struct {
	FormatVersion string                  `json:"formatVersion"`
	Products      map[string]Product      `json:"products"`
	Terms         Terms                   `json:"terms"`
	PublicationDate string                `json:"publicationDate"`
}

// Product represents a single product in the pricing data
type Product struct {
	SKU           string            `json:"sku"`
	ProductFamily string            `json:"productFamily"`
	Attributes    map[string]string `json:"attributes"`
}

// Terms contains pricing terms (OnDemand, Reserved, etc.)
type Terms struct {
	OnDemand map[string]map[string]OnDemandTerm `json:"OnDemand"`
}

// OnDemandTerm represents on-demand pricing terms
type OnDemandTerm struct {
	OfferTermCode   string                     `json:"offerTermCode"`
	SKU             string                     `json:"sku"`
	PriceDimensions map[string]PriceDimension  `json:"priceDimensions"`
}

// PriceDimension represents a pricing dimension (e.g., per hour, per GB)
type PriceDimension struct {
	Unit         string            `json:"unit"`
	PricePerUnit map[string]string `json:"pricePerUnit"` // currency -> price string
	Description  string            `json:"description"`
}

// PriceCache defines interface for caching pricing data
type PriceCache interface {
	Get(query PriceQuery) (PriceResult, bool)
	Set(query PriceQuery, result PriceResult)
	Clear() error
}
// Package terratestsmoke is a toolchain smoke fixture for US-0-GOTT.
// It proves the container (or host) Go lane can reach LocalStack. Real
// Terratest suites belong to US-S18 — do not expand this into S18 content.
package terratestsmoke

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"testing"
	"time"
)

func TestLocalStackHealthy(t *testing.T) {
	t.Parallel()

	endpoint := os.Getenv("AWS_ENDPOINT_URL")
	if endpoint == "" {
		endpoint = "http://localhost:4566"
	}
	url := endpoint + "/_localstack/health"

	client := &http.Client{Timeout: 5 * time.Second}
	var lastErr error
	for attempt := 1; attempt <= 30; attempt++ {
		resp, err := client.Get(url)
		if err != nil {
			lastErr = err
			time.Sleep(2 * time.Second)
			continue
		}
		if resp.StatusCode != http.StatusOK {
			_ = resp.Body.Close()
			lastErr = fmt.Errorf("status %d", resp.StatusCode)
			time.Sleep(2 * time.Second)
			continue
		}
		var body map[string]any
		decErr := json.NewDecoder(resp.Body).Decode(&body)
		_ = resp.Body.Close()
		if decErr != nil {
			t.Fatalf("decode LocalStack health JSON: %v", decErr)
		}
		t.Logf("LocalStack healthy at %s (keys=%d)", url, len(body))
		return
	}
	t.Fatalf("LocalStack not healthy at %s after retries: %v", url, lastErr)
}

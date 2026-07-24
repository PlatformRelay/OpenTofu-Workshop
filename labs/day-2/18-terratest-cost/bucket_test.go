// Terratest e2e for S18 — apply → assert → destroy against LocalStack.
// Run via the pinned container lane (no host Go required):
//
//	task lab:terratest DIR=labs/day-2/18-terratest-cost
package test

import (
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

func TestLocalStackS3Bucket(t *testing.T) {
	endpoint := os.Getenv("AWS_ENDPOINT_URL")
	if endpoint == "" {
		endpoint = "http://localhost:4566"
	}

	opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformBinary: "tofu",
		TerraformDir:    ".",
		NoColor:         true,
		Vars: map[string]interface{}{
			"project":      "crmapp",
			"aws_endpoint": endpoint,
		},
		EnvVars: map[string]string{
			"AWS_ACCESS_KEY_ID":     "test",
			"AWS_SECRET_ACCESS_KEY": "test",
			"AWS_DEFAULT_REGION":     "us-east-1",
		},
	})

	defer terraform.Destroy(t, opts)

	terraform.InitAndApply(t, opts)

	bucket := terraform.Output(t, opts, "bucket_name")
	require.True(t, strings.HasPrefix(bucket, "s3-crmapp-"),
		"expected bucket name to start with s3-crmapp-, got %q", bucket)
	require.Equal(t, "s3-crmapp-d-web-tt", bucket)
}

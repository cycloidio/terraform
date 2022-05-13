package etcdv2

import (
	"testing"

	"github.com/cycloidio/terraform/backend"
)

func TestBackend_impl(t *testing.T) {
	var _ backend.Backend = new(Backend)
}

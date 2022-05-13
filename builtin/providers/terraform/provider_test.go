package terraform

import (
	backendInit "github.com/cycloidio/terraform/backend/init"
)

func init() {
	// Initialize the backends
	backendInit.Init(nil)
}

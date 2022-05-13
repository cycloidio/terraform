package main

import (
	"github.com/cycloidio/terraform/builtin/providers/terraform"
	"github.com/cycloidio/terraform/grpcwrap"
	"github.com/cycloidio/terraform/plugin"
	"github.com/cycloidio/terraform/tfplugin5"
)

func main() {
	// Provide a binary version of the internal terraform provider for testing
	plugin.Serve(&plugin.ServeOpts{
		GRPCProviderFunc: func() tfplugin5.ProviderServer {
			return grpcwrap.Provider(terraform.NewProvider())
		},
	})
}

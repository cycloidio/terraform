package main

import (
	"github.com/cycloidio/terraform/grpcwrap"
	"github.com/cycloidio/terraform/plugin"
	simple "github.com/cycloidio/terraform/provider-simple"
	"github.com/cycloidio/terraform/tfplugin5"
)

func main() {
	plugin.Serve(&plugin.ServeOpts{
		GRPCProviderFunc: func() tfplugin5.ProviderServer {
			return grpcwrap.Provider(simple.Provider())
		},
	})
}

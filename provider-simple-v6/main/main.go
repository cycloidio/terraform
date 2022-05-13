package main

import (
	"github.com/cycloidio/terraform/grpcwrap"
	plugin "github.com/cycloidio/terraform/plugin6"
	simple "github.com/cycloidio/terraform/provider-simple-v6"
	"github.com/cycloidio/terraform/tfplugin6"
)

func main() {
	plugin.Serve(&plugin.ServeOpts{
		GRPCProviderFunc: func() tfplugin6.ProviderServer {
			return grpcwrap.Provider6(simple.Provider())
		},
	})
}

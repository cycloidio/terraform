package main

import (
	"github.com/hashicorp/terraform/grpcwrap"
	"github.com/hashicorp/terraform/plugin"
	simple "github.com/hashicorp/terraform/provider-simple"
	"github.com/hashicorp/terraform/tfplugin5"
)

func main() {
	plugin.Serve(&plugin.ServeOpts{
		GRPCProviderFunc: func() tfplugin5.ProviderServer {
			return grpcwrap.Provider(simple.Provider())
		},
	})
}

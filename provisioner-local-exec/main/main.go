package main

import (
	localexec "github.com/cycloidio/terraform/builtin/provisioners/local-exec"
	"github.com/cycloidio/terraform/grpcwrap"
	"github.com/cycloidio/terraform/plugin"
	"github.com/cycloidio/terraform/tfplugin5"
)

func main() {
	// Provide a binary version of the internal terraform provider for testing
	plugin.Serve(&plugin.ServeOpts{
		GRPCProvisionerFunc: func() tfplugin5.ProvisionerServer {
			return grpcwrap.Provisioner(localexec.New())
		},
	})
}

// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: BUSL-1.1

package providers

import (
	terraformProvider "github.com/hashicorp/terraform/builtin/providers/terraform"
	provider "github.com/hashicorp/terraform/providers"
)

func BuiltInProviders() map[string]provider.Factory {
	return map[string]provider.Factory{
		"terraform": func() (provider.Interface, error) {
			return terraformProvider.NewProvider(), nil
		},
	}
}

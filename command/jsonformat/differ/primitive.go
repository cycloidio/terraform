package differ

import (
	"github.com/zclconf/go-cty/cty"

	"github.com/hashicorp/terraform/command/jsonformat/computed"
	"github.com/hashicorp/terraform/command/jsonformat/computed/renderers"
	"github.com/hashicorp/terraform/command/jsonformat/structured"
)

func computeAttributeDiffAsPrimitive(change structured.Change, ctype cty.Type) computed.Diff {
	return asDiff(change, renderers.Primitive(change.Before, change.After, ctype))
}

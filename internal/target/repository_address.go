package target

import (
	"context"

	"github.com/hashicorp/boundary/internal/db"
	"github.com/hashicorp/boundary/internal/errors"
)

func fetchStaticAddress(ctx context.Context, r db.Reader, targetId string) (StaticAddress, error) {
	const op = "target.fetchStaticAddress"
	var staticAddress *TargetAddress
	if err := r.SearchWhere(ctx, &staticAddress, "public_id = ?", []interface{}{targetId}); err != nil {
		return nil, errors.Wrap(ctx, err, op)
	}
	if staticAddress == nil {
		return nil, nil
	}
	return staticAddress, nil
}

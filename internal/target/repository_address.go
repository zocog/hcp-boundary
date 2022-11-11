package target

import (
	"context"

	"github.com/hashicorp/boundary/internal/db"
	"github.com/hashicorp/boundary/internal/errors"
)

func fetchAddress(ctx context.Context, r db.Reader, targetId string) (*Address, error) {
	const op = "target.fetchAddress"
	var address *Address
	if err := r.SearchWhere(ctx, &address, "target_id = ?", []interface{}{targetId}); err != nil {
		return nil, errors.Wrap(ctx, err, op)
	}
	if address.TargetAddress == nil {
		return nil, nil
	}
	return address, nil
}

package target

import (
	"context"

	"github.com/golang/protobuf/proto"
	"github.com/hashicorp/boundary/internal/db"
	"github.com/hashicorp/boundary/internal/errors"
	"github.com/hashicorp/boundary/internal/oplog"
	"github.com/hashicorp/boundary/internal/target/store"
)

// StaticAddress is an interface that can be implemented by a TargetAddress.
type StaticAddress interface {
	PublicId() string
	Address() string
}

var _ StaticAddress = (*TargetAddress)(nil)

const (
	DefaultTargetAddressTableName = "target_address"
)

// A TargetAddress represents the relationship between a target and a
// network address.
type TargetAddress struct {
	*store.TargetAddress
	tableName string `gorm:"-"`
}

var _ db.VetForWriter = (*TargetAddress)(nil)

// NewTargetAddress creates a new in memory target address. No options are
// currently supported.
func NewTargetAddress(publicId, address string, _ ...Option) (*TargetAddress, error) {
	const op = "target.NewTargetAddress"
	if publicId == "" {
		return nil, errors.NewDeprecated(errors.InvalidParameter, op, "missing public id")
	}
	if address == "" {
		return nil, errors.NewDeprecated(errors.InvalidParameter, op, "missing address")
	}
	t := &TargetAddress{
		TargetAddress: &store.TargetAddress{
			PublicId: publicId,
			Address:  address,
		},
	}
	return t, nil
}

// Clone create a clone of the target address
func (t *TargetAddress) Clone() interface{} {
	cp := proto.Clone(t.TargetAddress)
	return &TargetAddress{
		TargetAddress: cp.(*store.TargetAddress),
	}
}

// VetForWrite implements db.VetForWrite() interface and validates the target
// address before it's written.
func (t *TargetAddress) VetForWrite(ctx context.Context, _ db.Reader, opType db.OpType, _ ...db.Option) error {
	const op = "target.(TargetAddress).VetForWrite"
	if opType == db.CreateOp {
		if t.GetPublicId() == "" {
			return errors.New(ctx, errors.InvalidParameter, op, "missing public id")
		}
		if t.GetAddress() == "" {
			return errors.New(ctx, errors.InvalidParameter, op, "missing address")
		}
	}
	return nil
}

// TableName returns the tablename to override the default gorm table name
func (t *TargetAddress) TableName() string {
	if t.tableName != "" {
		return t.tableName
	}
	return DefaultTargetAddressTableName
}

// SetTableName sets the tablename and satisfies the ReplayableMessage
// interface. If the caller attempts to set the name to "" the name will be
// reset to the default name.
func (t *TargetAddress) SetTableName(n string) {
	t.tableName = n
}

func (t *TargetAddress) oplog(op oplog.OpType) oplog.Metadata {
	metadata := oplog.Metadata{
		"resource-public-id": []string{t.GetPublicId()},
		"resource-type":      []string{"target address"},
		"op-type":            []string{op.String()},
	}
	return metadata
}

func (t *TargetAddress) PublicId() string {
	return t.GetPublicId()
}

func (t *TargetAddress) Address() string {
	return t.GetAddress()
}

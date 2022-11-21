package session

import "github.com/hashicorp/boundary/internal/errors"

const (
	defaultSessionTargetAddressTableName = "session_target_address"
)

// SessionTargetAddress contains information about a user's session with a target that has a direct network address association.
type SessionTargetAddress struct {
	// PublicId is the session id
	PublicId string `json:"public_id,omitempty" gorm:"primary_key"`
	// TargetId for the session
	TargetId string `json:"target_id,omitempty" gorm:"default:null"`

	tableName string `gorm:"-"`
}

// NewSessionTargetAddress creates a new in memory session target address.
func NewSessionTargetAddress(publicId, targetId string) (*SessionTargetAddress, error) {
	const op = "sesssion.NewSessionTargetAddress"
	if publicId == "" {
		return nil, errors.NewDeprecated(errors.InvalidParameter, op, "missing public id")
	}
	if targetId == "" {
		return nil, errors.NewDeprecated(errors.InvalidParameter, op, "missing target id")
	}
	sta := &SessionTargetAddress{
		PublicId: publicId,
		TargetId: targetId,
	}
	return sta, nil
}

// TableName returns the tablename to override the default gorm table name
func (s *SessionTargetAddress) TableName() string {
	if s.tableName != "" {
		return s.tableName
	}
	return defaultSessionTargetAddressTableName
}

// SetTableName sets the tablename and satisfies the ReplayableMessage
// interface. If the caller attempts to set the name to "" the name will be
// reset to the default name.
func (s *SessionTargetAddress) SetTableName(n string) {
	s.tableName = n
}

// AllocSessionTargetAddress will allocate a SessionTargetAddress
func AllocSessionTargetAddress() SessionTargetAddress {
	return SessionTargetAddress{}
}

// Clone creates a clone of the SessionTargetAddress
func (s *SessionTargetAddress) Clone() interface{} {
	clone := &SessionTargetAddress{
		PublicId: s.PublicId,
		TargetId: s.TargetId,
	}
	return clone
}

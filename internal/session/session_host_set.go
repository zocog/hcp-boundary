package session

import "github.com/hashicorp/boundary/internal/errors"

const (
	defaultSessionHostSetTableName = "session_host_set"
)

// SessionHostSet contains information about a user's session with a target that has a host set association.
type SessionHostSet struct {
	// PublicId is the session id
	PublicId string `json:"public_id,omitempty" gorm:"primary_key"`
	// HostSetId for the session
	HostSetId string `json:"host_set_id,omitempty" gorm:"default:null"`

	tableName string `gorm:"-"`
}

func NewSessionHostSet(publicId, hostSetId string) (*SessionHostSet, error) {
	const op = "session.NewSessionHostSet"
	if publicId == "" {
		return nil, errors.NewDeprecated(errors.InvalidParameter, op, "missing public id")
	}
	if hostSetId == "" {
		return nil, errors.NewDeprecated(errors.InvalidParameter, op, "missing host set id")
	}
	shs := &SessionHostSet{
		PublicId:  publicId,
		HostSetId: hostSetId,
	}
	return shs, nil
}

// TableName returns the tablename to override the default gorm table name
func (s *SessionHostSet) TableName() string {
	if s.tableName != "" {
		return s.tableName
	}
	return defaultSessionHostSetTableName
}

// SetTableName sets the tablename and satisfies the ReplayableMessage
// interface. If the caller attempts to set the name to "" the name will be
// reset to the default name.
func (s *SessionHostSet) SetTableName(n string) {
	s.tableName = n
}

// AllocSessionHostSet will allocate a SessionHostSet
func AllocSessionHostSet() SessionHostSet {
	return SessionHostSet{}
}

// Clone creates a clone of the SessionHostSet
func (s *SessionHostSet) Clone() interface{} {
	clone := &SessionHostSet{
		PublicId:  s.PublicId,
		HostSetId: s.HostSetId,
	}
	return clone
}

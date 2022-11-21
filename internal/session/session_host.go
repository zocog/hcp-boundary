package session

import "github.com/hashicorp/boundary/internal/errors"

const (
	defaultSessionHostTableName = "session_host"
)

// SessionHost contains information about a user's session with a target that has a host association.
type SessionHost struct {
	// PublicId is the session id
	PublicId string `json:"public_id,omitempty" gorm:"primary_key"`
	// HostId for the session
	HostId string `json:"host_id,omitempty" gorm:"default:null"`

	tableName string `gorm:"-"`
}

func NewSessionHost(publicId, hostId string) (*SessionHost, error) {
	const op = "session.NewSessionHost"
	if publicId == "" {
		return nil, errors.NewDeprecated(errors.InvalidParameter, op, "missing public id")
	}
	if hostId == "" {
		return nil, errors.NewDeprecated(errors.InvalidParameter, op, "missing host id")
	}
	sh := &SessionHost{
		PublicId: publicId,
		HostId:   hostId,
	}
	return sh, nil
}

// TableName returns the tablename to override the default gorm table name
func (s *SessionHost) TableName() string {
	if s.tableName != "" {
		return s.tableName
	}
	return defaultSessionHostTableName
}

// SetTableName sets the tablename and satisfies the ReplayableMessage
// interface. If the caller attempts to set the name to "" the name will be
// reset to the default name.
func (s *SessionHost) SetTableName(n string) {
	s.tableName = n
}

// AllocSessionHost will allocate a SessionHost
func AllocSessionHost() *SessionHost {
	return &SessionHost{}
}

// Clone creates a clone of the SessionHost
func (s *SessionHost) Clone() interface{} {
	clone := &SessionHost{
		PublicId: s.PublicId,
		HostId:   s.HostId,
	}
	return clone
}

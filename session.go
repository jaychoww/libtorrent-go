package libtorrent

// Session is a wrapper for libtorrent::session
type Session interface {
	WrappedSession
	GetHandle() (SessionHandle, error)
}

// SessionImpl ...
type SessionImpl struct {
	WrappedSession
}

// NewSession is a wrapper for libtorrent::session
func NewSession(a ...interface{}) (ret Session, err error) {
	defer catch(&err)

	ret = SessionImpl{NewWrappedSession(a...)}
	return
}

// DeleteSession is a wrapper for libtorrent::session
func DeleteSession(arg1 Session) (err error) {
	defer catch(&err)

	DeleteWrappedSession(arg1)
	return
}

// GetHandle is a wrapper for libtorrent::session::get_handle
func (p SessionImpl) GetHandle() (ret SessionHandle, err error) {
	defer catch(&err)

	ret = SessionHandleImpl{p.WrappedGetHandle()}
	return
}

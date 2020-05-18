package libtorrent

// SessionHandle is a wrapper for libtorrent::session_handle
type SessionHandle interface {
	WrappedSessionHandle
	AddTorrent(...interface{}) (TorrentHandle, error)
	AsyncAddTorrent(AddTorrentParams) error
	RemoveTorrent(...interface{}) error
}

// SessionHandleImpl ...
type SessionHandleImpl struct {
	WrappedSessionHandle
}

// AddTorrent is a wrapper for libtorrent::session_handle::add_torrent
func (p SessionHandleImpl) AddTorrent(a ...interface{}) (ret TorrentHandle, err error) {
	defer catch(&err)

	ret = TorrentHandleImpl{p.WrappedAddTorrent(a...)}
	return
}

// AsyncAddTorrent is a wrapper for libtorrent::session_handle::async_add_torrent
func (p SessionHandleImpl) AsyncAddTorrent(arg2 AddTorrentParams) (err error) {
	defer catch(&err)

	p.WrappedAsyncAddTorrent(arg2)
	return
}

// RemoveTorrent is a wrapper for libtorrent::session_handle::remove_torrent
func (p SessionHandleImpl) RemoveTorrent(a ...interface{}) (err error) {
	defer catch(&err)

	p.WrappedRemoveTorrent(a...)
	return
}

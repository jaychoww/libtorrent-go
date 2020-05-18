package libtorrent

// TorrentHandle is a wrapper for libtorrent::torrent_handle
type TorrentHandle interface {
	WrappedTorrentHandle
}

// TorrentHandleImpl ...
type TorrentHandleImpl struct {
	WrappedTorrentHandle
}

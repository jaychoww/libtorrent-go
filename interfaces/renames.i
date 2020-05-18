%rename("%(camelcase)s", %$isclass) "";
%rename("%(camelcase)s", %$isvariable) "";
%rename("%(camelcase)s", %$isenumitem) "";
%rename("%(camelcase)s", %$isenum) "";
%rename("%(camelcase)s", %$istemplate) "";
%rename("%(camelcase)s", %$isfunction) "";
%rename("%(camelcase)s", %$isnamespace) "";

// Renaming C++ classes to Wrapped*, 
// so later they can be wrapped with Go native structs to catch exceptions.

%rename(WrappedSession) libtorrent::session;
%rename(WrappedGetHandle) libtorrent::session::get_handle;

%rename(WrappedSessionHandle) libtorrent::session_handle;
%rename(WrappedAddTorrent) libtorrent::session_handle::add_torrent;
%rename(WrappedRemoveTorrent) libtorrent::session_handle::remove_torrent;
%rename(WrappedAsyncAddTorrent) libtorrent::session_handle::async_add_torrent;

%rename(WrappedTorrentHandle) libtorrent::torrent_handle;


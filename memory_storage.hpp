
#ifndef TORRENT_MEMORY_STORAGE_HPP_INCLUDED
#define TORRENT_MEMORY_STORAGE_HPP_INCLUDED

#include <chrono>
#include <math.h>
#include <memory>

#include <boost/dynamic_bitset.hpp>
#include <boost/thread/mutex.hpp>

#include <libtorrent/error_code.hpp>
#include <libtorrent/bencode.hpp>
#include <libtorrent/storage.hpp>
#include <libtorrent/storage_defs.hpp>
#include <libtorrent/block_cache.hpp>
#include <libtorrent/fwd.hpp>
#include <libtorrent/file.hpp>
#include <libtorrent/entry.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/torrent_handle.hpp>
#include <libtorrent/torrent.hpp>

typedef boost::dynamic_bitset<> Bitset;

using namespace libtorrent;

namespace libtorrent {
        std::int64_t memory_size = 0;

        std::chrono::milliseconds now() {
                return std::chrono::duration_cast< std::chrono::milliseconds >(
                        std::chrono::system_clock::now().time_since_epoch()
                );
        }

        struct memory_piece 
        {
        // private:
        //         boost::mutex m_mutex;
        public:
                int index;
                int length;

                int size = 0;
                int bi = -1;
                bool is_completed = false;
                bool is_read = false;

                memory_piece(int i, int length) : index(i), length(length) {};

                bool is_buffered() {
                        return bi != -1;
                };

                void reset() {
                        bi = -1;
                        is_completed = false;
                        is_read = false;
                        size = 0;

                        std::cerr << "INFO Freeing piece " << index << std::endl;
                }
        };

        struct memory_buffer 
        {
        // private:
        //         boost::mutex m_mutex;
        public:
                int index = -1;
                int length = 0;
                std::vector<char> buffer;

                int pi = -1;
                bool is_used = false;
                std::chrono::milliseconds accessed;

                memory_buffer(int index, int length) : index(index), length(length) {
                        buffer.resize(length);
                };

                bool is_assigned() {
                        return pi != -1;
                };

                void reset() {
                        is_used = false;
                        pi = -1;
                        accessed = now();

                        std::cerr << "INFO Freeing buffer " << index << std::endl;
                };
        };

        struct memory_storage : storage_interface
        {
        private:
                boost::mutex m_mutex;
        public:
                Bitset reader_pieces;
                Bitset reserved_pieces;

                std::string id;
                std::int64_t capacity;

                int piece_count = 0;
                std::int64_t piece_length = 0;
                std::vector<memory_piece> pieces;

                int buffer_size = 0;
                int buffer_limit = 0;
                int buffer_used = 0;
                int buffer_reserved = 0;
                std::vector<memory_buffer> buffers;

                file_storage const* m_files;
                torrent_info const* m_info;
                libtorrent::torrent_handle* m_handle;

                bool is_logging = false;
                bool is_initialized = false;
                bool is_reading = false;

                memory_storage(storage_params const& params) {
                        m_files = params.files;
                        m_info = params.info;

                        capacity = memory_size;
                        piece_count = m_info->num_pieces();
                        piece_length = m_info->piece_length();

                        std::cerr << "INFO Init with mem size " << memory_size << ", Pieces: " << piece_count <<
                                ", Piece length: " << piece_length << std::endl;

                        for (int i = 0; i < piece_count; i++) {
                                pieces.push_back(memory_piece(i, m_info->piece_size(i)));
                        }

                        // Using max possible buffers + 2
                        buffer_size = rint(ceil(capacity/piece_length) + 2);
                        if (buffer_size > piece_count) {
                                buffer_size = piece_count;
                        };
                        buffer_limit = buffer_size;
                        std::cerr << "INFO Using " << buffer_size << " buffers" << std::endl;

                        for (int i = 0; i < buffer_size; i++) {
                                buffers.push_back(memory_buffer(i, piece_length));
                        }

                        reader_pieces.resize(piece_count+10);
                        reserved_pieces.resize(piece_count+10);

                        is_initialized = true;
                };

                ~memory_storage() {};

                void initialize(storage_error& ec) {}

                void set_memory_size(std::int64_t s) {
                        if (s <= capacity) return;

                        boost::unique_lock<boost::mutex> scoped_lock(m_mutex);

                        capacity = s;

                        int prev_buffer_size = buffer_size;

                        // Using max possible buffers + 2
                        buffer_size = rint(ceil(capacity/piece_length) + 2);
                        if (buffer_size > piece_count) {
                                buffer_size = piece_count;
                        };
                        buffer_limit = buffer_size;
                        if (prev_buffer_size == buffer_size) {
                                std::cerr << "INFO Not increasing buffer due to same size (" << buffer_size << ")" << std::endl;
                                return;
                        };

                        std::cerr << "INFO Increasing buffer to " << buffer_size << " buffers" << std::endl;

                        for (int i = prev_buffer_size - 1; i < buffer_size; i++) {
                                buffers.push_back(memory_buffer(i, piece_length));
                        }
                }

                // bool has_any_file() { 
                //         if (logging) {
                //                 std::cerr << "INFO has_any_file" << std::endl;
                //         };
                //         return false; 
                // }

                int read(char* read_buf, int size, int piece, int offset) {
                        if (!is_initialized) return 0;
                        is_reading = true;

                        if (is_logging) {
                                printf("Read start: %d, off: %d, size: %d \n", piece, offset, size);
                        };

                        if (!get_read_buffer(&pieces[piece])) {
                                std::cerr << "INFO nobuffer" << piece << ", off: " << offset << std::endl;
                                restore_piece(piece);
                                return -1;
                        };
                        if (pieces[piece].size < pieces[piece].length) {
                                std::cerr << "INFO less: " << piece << ", off: " << offset << ", size: " << pieces[piece].size << ", length: " << pieces[piece].length << std::endl;
                                restore_piece(piece);
                                return -1;
                        };

                        int available = buffers[pieces[piece].bi].buffer.size() - offset;
                        if (available <= 0) return 0;
                        if (available > size) available = size;

                        if (is_logging) {
                                printf("       pre: %d, off: %d, size: %d, available: %d, sizeof: %d \n", piece, offset, size, available, int(sizeof(read_buf)));
                        };
                        memcpy(read_buf, &buffers[pieces[piece].bi].buffer[offset], available);

                        if (pieces[piece].is_completed && offset+available >= pieces[piece].size) {
                                pieces[piece].is_read = true;
                        };

                        buffers[pieces[piece].bi].accessed = now();

                        return size;
                };

                int readv(libtorrent::file::iovec_t const* bufs, int num_bufs
                        , int piece, int offset, int flags, libtorrent::storage_error& ec)
                {
                        if (!is_initialized) return 0;

                        if (is_logging) {
                                printf("Read piece: %d, off: %d \n", piece, offset);
                        };

                        if (!get_read_buffer(&pieces[piece])) {
                                std::cerr << "INFO noreadbuffer" << piece << std::endl;
                                return 0;
                        };

                        int file_offset = offset;
                        int n = 0;
                        for (int i = 0; i < num_bufs; ++i)
                        {
                                std::memcpy(bufs[i].iov_base, &buffers[pieces[piece].bi].buffer[file_offset], bufs[i].iov_len);
                                file_offset += bufs[i].iov_len;
                                n += bufs[i].iov_len;
                        };

                        if (pieces[piece].is_completed && offset+n >= pieces[piece].size) {
                                pieces[piece].is_read = true;
                        };

                        buffers[pieces[piece].bi].accessed = now();

                        return n;
                };

                int writev(libtorrent::file::iovec_t const* bufs, int num_bufs
                        , int piece, int offset, int flags, libtorrent::storage_error& ec)
                {
                        if (!is_initialized) return 0;

                        if (is_logging) {
                                printf("Write Input: %d, off: %d, bufs: %d \n", piece, offset, bufs_size(bufs, num_bufs));
                        };

                        if (!get_write_buffer(&pieces[piece])) {
                                if (is_logging) {
                                        std::cerr << "INFO nowritebuffer" << piece << std::endl;
                                };
                                return 0;
                        };

                        int size = bufs_size(bufs, num_bufs);
                        if (buffers[pieces[piece].bi].buffer.size() < offset + size) 
                                buffers[pieces[piece].bi].buffer.resize(offset + size);

                        int file_offset = offset;
                        int n = 0;
                        for (int i = 0; i < num_bufs; ++i)
                        {
                                std::memcpy(&buffers[pieces[piece].bi].buffer[file_offset], bufs[i].iov_base, bufs[i].iov_len);
                                file_offset += bufs[i].iov_len;
                                n += bufs[i].iov_len;
                        };

                        pieces[piece].size += n;
                        buffers[pieces[piece].bi].accessed = now();

                        if (buffer_used >= buffer_limit) {
                                trim(piece);
                        }

                        return n;
                };

                void rename_file(int index, std::string const& new_filename
                        , libtorrent::storage_error& ec) {}

                bool move_storage(std::string const& save_path) { 
                        return false; 
                }

                bool verify_resume_data(libtorrent::bdecode_node const& rd
                        , std::vector<std::string> const* links
                        , libtorrent::storage_error& error) { 
                        return false; 
                }

                bool write_resume_data(libtorrent::entry& rd) const { 
                        return false; 
                }

                void write_resume_data(libtorrent::entry& rd, libtorrent::storage_error& ec) {
                }

                void release_files(libtorrent::storage_error& ec) {
                }

                bool delete_files() { 
                        return false; 
                }

                bool has_any_file(libtorrent::storage_error& ec) { 
                        if (is_logging) {
                                printf("Has 2 \n");
                        };
                        return false; 
                }

                void set_torrent_handle(libtorrent::torrent_handle* h) {
                        m_handle = h;
                }

                void set_file_priority(std::vector<boost::uint8_t>& prio, libtorrent::storage_error& ec) 
                {
                        if (is_logging) {
                                printf("Set prio \n");
                        };
                }

                int move_storage(std::string const& save_path, int flags, libtorrent::storage_error& ec) 
                { 
                        if (is_logging) {
                                printf("Move storage 2 \n");
                        };
                        return 0; 
                }

                void write_resume_data(libtorrent::entry& rd, libtorrent::storage_error& ec) const 
                {
                        if (is_logging) {
                                printf("Write resume 2 \n");
                        };
                }

                void delete_files(int options, libtorrent::storage_error& ec) {
                        if (is_logging) {
                                printf("Delete file 2 \n");
                        };
                };

                bool get_read_buffer(memory_piece* p) {
                        return get_buffer(p, false);
                };

                bool get_write_buffer(memory_piece* p) {
                        return get_buffer(p, true);
                };

                bool get_buffer(memory_piece *p, bool is_write) {
                        if (p->is_buffered()) {
                                return true;
                        } else if (!is_write) {
                                // Trying to lock and get to make sure we are not affected 
                                // by write/read at the same time.
                                boost::unique_lock<boost::mutex> scoped_lock(m_mutex);
                                return p->is_buffered();
                        }

                        boost::unique_lock<boost::mutex> scoped_lock(m_mutex);
                        // Once again checking in case we had multiple writes in parallel
                        if (p->is_buffered()) return true;

                        // Check if piece is not in reader ranges and avoid allocation
                        if (is_reading && !is_readered(p->index)) return false;

                        for (int i = 0; i < buffer_size; i++) {
                                if (buffers[i].is_used) {
                                        continue;
                                };

                                // if (is_logging) {
                                        // printf("Setting buffer %d to piece %d \n", buffers[i].index, p->index);
                                // };
                                std::cerr << "INFO Setting buffer " << buffers[i].index << " to piece " << p->index << std::endl;

                                buffers[i].is_used = true;
                                buffers[i].pi = p->index;
                                buffers[i].accessed = now();

                                p->bi = buffers[i].index;

                                // If we are placing permanent buffer entry - we should reduce the limit,
                                // to propely check for the usage.
                                if (reserved_pieces.test(p->index)) {
                                        buffer_limit--;
                                } else {
                                        buffer_used++;
                                };

                                break;
                        }

                        return p->is_buffered();
                };

                void trim(int pi) {
                        if (capacity < 0 || buffer_used < buffer_limit) {
                                return;
                        };

                        boost::unique_lock<boost::mutex> scoped_lock(m_mutex);

                        while (buffer_used >= buffer_limit) {
                                std::cerr << "INFO Trimming " << buffer_used << " to " << buffer_limit << " with reserved " << buffer_reserved << ", " << get_buffer_info() << std::endl;

                                if (!reader_pieces.empty()) {
                                        int bi = find_last_buffer(pi, true);
                                        if (bi != -1) {
                                                std::cerr << "INFO Removing non-read piece: " << buffers[bi].pi << ", buffer:" << bi << std::endl;
                                                remove_piece(bi);
                                                continue;
                                        }
                                }

                                int bi = find_last_buffer(pi, false);
                                if (bi != -1) {
                                        std::cerr << "INFO Removing LRU piece: " << buffers[bi].pi << ", buffer:" << bi << std::endl;
                                        remove_piece(bi);
                                        continue;
                                }
                        }
                };

                std::string get_buffer_info() {
                        std::string result = "";
                        
                        for (auto it = buffers.begin(); it != buffers.end(); ++it) 
                        {
                                if (!result.empty()) result += " ";

                                result += std::to_string(it->index) + ":" + std::to_string(it->pi);
                        };

                        return result;
                };

                int find_last_buffer(int pi, bool check_read) {
                        int bi = -1;
                        std::chrono::milliseconds minTime = now();

                        for (auto it = buffers.begin(); it != buffers.end(); ++it) 
                        {
                                if (it->is_used && it->is_assigned() 
                                        && !is_reserved(it->pi) 
                                        && it->pi != pi
                                        && (!check_read || !is_readered(it->pi))
                                        && it->accessed <= minTime) {
                                        bi = it->index;
                                        minTime = it->accessed;
                                };
                        };

                        return bi;
                }

                void remove_piece(int bi) {
                        int pi = buffers[bi].pi;

                        buffers[bi].reset();
                        buffer_used--;
                        
                        if (pi != -1 && pi < piece_count) {
                                pieces[pi].reset();
                                restore_piece(pi);
                        }
                }
                
                void restore_piece(int pi) {
                        if (!m_handle) return;

                        libtorrent::torrent* t = m_handle->native_handle().get();
                        if (!t) return;

                        std::cerr << "INFO Restoring piece: " << pi << std::endl;
                        // t->picker().reset_piece(pi);
                        t->picker().set_piece_priority(pi, 0);
                        t->picker().we_dont_have(pi);
                }

                void enable_logging() {
                        is_logging = true;
                }

                void disable_logging() {
                        is_logging = false;
                }

                void update_reader_pieces(std::vector<int> pieces) {
                        if (!is_initialized) return;

                        boost::unique_lock<boost::mutex> scoped_lock(m_mutex);
                        reader_pieces.reset();
                        for (auto i = pieces.begin(); i != pieces.end(); ++i) {
                                reader_pieces.set(*i);
                        };
                };

                void update_reserved_pieces(std::vector<int> pieces) {
                        if (!is_initialized) return;

                        boost::unique_lock<boost::mutex> scoped_lock(m_mutex);
                        buffer_reserved = 0;
                        reserved_pieces.reset();
                        for (auto i = pieces.begin(); i != pieces.end(); ++i) {
                                reserved_pieces.set(*i);
                                buffer_reserved++;
                        };
                };

                bool is_reserved(int index) {
                        if (!is_initialized) return false;

                        return reserved_pieces.test(index);
                };

                bool is_readered(int index) {
                        if (!is_initialized) return false;
                        
                        return reader_pieces.test(index);
                };
        };

        storage_interface* memory_storage_constructor(storage_params const& params)
        {
                return new memory_storage(params);
        };
}

#endif // TORRENT_MEMORY_STORAGE_HPP_INCLUDED

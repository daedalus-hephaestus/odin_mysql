package mysql

import "core:encoding/endian"
import "core:fmt"
import "core:math"
import "core:net"
import "core:slice"
import "core:strings"

Capabilities :: enum {
	CLIENT_LONG_PASSWORD,
	CLIENT_FOUND_ROWS,
	CLIENT_LONG_FLAG,
	CLIENT_CONNECT_WITH_DB,
	CLIENT_NO_SCHEMA,
	CLIENT_COMPRESS,
	CLIENT_ODBC,
	CLIENT_LOCAL_FILES,
	CLIENT_IGNORE_SPACE,
	CLIENT_PROTOCOL_41,
	CLIENT_INTERACTIVE,
	CLIENT_SSL,
	CLIENT_IGNORE_SIGPIPE,
	CLIENT_TRANSACTIONS,
	CLIENT_RESERVED,
	CLIENT_SECURE_CONNECTION,
	CLIENT_MULTI_STATEMENTS,
	CLIENT_MULTI_RESULTS,
	CLIENT_PS_MULTI_RESULTS,
	CLIENT_PLUGIN_AUTH,
	CLIENT_CONNECT_ATTRS,
	CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA,
	CLIENT_CAN_HANDLE_EXPIRED_PASSWORDS,
	CLIENT_SESSION_TRACK,
	CLIENT_DEPRECATE_EOF,
	CLIENT_OPTIONAL_RESULTSET_METADATA,
	CLIENT_ZSTD_COMPRESSION_ALGORITHM,
	CLIENT_QUERY_ATTRIBUTES,
	MULTI_FACTOR_AUTHENTICATION,
	CLIENT_CAPABILITY_EXTENSION,
	CLIENT_SSL_VERIFY_SERVER_CERT,
	CLIENT_REMEMBER_OPTIONS,
}

Status :: enum {
	SERVER_STATUS_IN_TRANS,
	SERVER_STATUS_AUTOCOMMIT,
	SERVER_MORE_RESULTS_EXISTS,
	SERVER_QUERY_NO_GOOD_INDEX_USED,
	SERVER_QUERY_NO_INDEX_USED,
	SERVER_STATUS_CURSOR_EXISTS,
	SERVER_STATUS_LAST_ROW_SENT,
	SERVER_STATUS_DB_DROPPED,
	SERVER_STATUS_NO_BACKSLASH_ESCAPES,
	SERVER_STATUS_METADATA_CHANGED,
	SERVER_QUERY_WAS_SLOW,
	SERVER_PS_OUT_PARAMS,
	SERVER_STATUS_IN_TRANS_READONLY,
	SERVER_SESSION_STATE_CHANGED,
}

HandshakeParseError :: enum {
	NONE,
	PARSE_ID,
	PARSE_CAPABILITIES_UPPER,
	PARSE_CAPABILITIES_LOWER,
	PARSE_STATUS,
	BUFFER_LENGTH,
	EXPECTED_ZERO,
	CONCAT_OUT_OF_MEMORY,
	CONCAT_INVALID_POINTER,
	CONCAT_INVALID_ARGUMENT,
	CONCAT_MODE_NOT_IMPLEMENTED,
}

TCP_Handshake :: struct {
	protocol_version:      u8,
	server_version:        string,
	thread_id:             u32,
	auth_plugin_data:      string,
	filler:                u8,
	capability_flag_bytes: u32,
	capability_flags:      [Capabilities]bool,
	character_set:         u8,
	status_flag_bytes:     u16,
	status_flags:          [Status]bool,
	auth_plugin_data_len:  u8,
	reserved:              string,
	auth_plugin_name:      string,
}

TCP_HandshakeResponse :: struct {
	client_flags:           [Capabilities]bool,
	max_packet_size:        u32,
	character_set:          u8,
	username:               string,
	auth_response:          string,
	auth_response_length:   u8,
	database:               string,
	client_plugin_name:     string,
	length_of_key_values:   u64,
	client_attributes:      []ClientAttribute,
	zstd_compression_level: u8,
}

ClientAttribute :: struct {
	key:   string,
	value: string,
}

encode_client_attributes :: proc (attributes: []ClientAttribute) -> []u8 {
	res : [dynamic]u8
	data : [dynamic]u8

	for a in attributes {
		key := encode_str_lenenc(a.key)
		defer delete(key)
		value := encode_str_lenenc(a.value)
		defer delete(value)

		append(&data, ..key[:])
		append(&data, ..value[:])
	}

	len := encode_int_lenenc(u64(len(data)))
	defer delete(len)

	append(&res, ..len[:])
	append(&res, ..data[:])


	return res[:]
}

parse_handshake :: proc(buff: []u8) -> (handshake: TCP_Handshake, err: HandshakeParseError) {
	i: int
	range_ok: bool

	handshake.protocol_version, i, range_ok = read_byte_inc(i, buff)
	if !range_ok {
		err = .BUFFER_LENGTH
		return
	}

	server_version: []u8
	server_version, i, range_ok = read_null_string_inc(i, buff)
	if !range_ok {
		err = .BUFFER_LENGTH
		return
	}
	handshake.server_version = string(server_version)

	thread_id_buff: []u8
	thread_id_buff, i, range_ok = read_bytes_inc(i, 4, buff)
	if !range_ok {
		err = .BUFFER_LENGTH
		return
	}
	thread_id, thread_ok := endian.get_u32(thread_id_buff, .Little)
	if !thread_ok {
		err = .PARSE_ID
		return
	}
	handshake.thread_id = thread_id

	auth_data_start: []u8
	auth_data_start, i, range_ok = read_bytes_inc(i, 8, buff)
	if !range_ok {
		err = .BUFFER_LENGTH
		return
	}

	handshake.filler, i, range_ok = read_byte_inc(i, buff)
	if !range_ok {
		err = .BUFFER_LENGTH
		return
	}

	cap_flags_lower_buff: []u8
	cap_flags_lower_buff, i, range_ok = read_bytes_inc(i, 2, buff)
	if !range_ok {
		err = .BUFFER_LENGTH
		return
	}
	cap_flags_lower, lower_ok := endian.get_u16(cap_flags_lower_buff, .Little)
	if !lower_ok {
		err = .PARSE_CAPABILITIES_LOWER
		return
	}

	handshake.character_set, i, range_ok = read_byte_inc(i, buff)
	if !range_ok {
		err = .BUFFER_LENGTH
		return
	}

	status_flag_buff: []u8
	status_flag_buff, i, range_ok = read_bytes_inc(i, 2, buff)
	if !range_ok {
		err = .BUFFER_LENGTH
		return
	}
	status_flag_bytes, status_ok := endian.get_u16(status_flag_buff, .Little)
	if !status_ok {
		err = .PARSE_STATUS
		return
	}
	handshake.status_flag_bytes = status_flag_bytes

	for s in Status {
		handshake.status_flags[s] = stat_mask(s) & handshake.status_flag_bytes != 0
	}

	cap_flags_upper_buff: []u8
	cap_flags_upper_buff, i, range_ok = read_bytes_inc(i, 2, buff)
	if !range_ok {
		err = .BUFFER_LENGTH
		return
	}
	cap_flags_upper, upper_ok := endian.get_u16(cap_flags_upper_buff, .Little)
	if !upper_ok {
		err = .PARSE_CAPABILITIES_UPPER
		return
	}

	handshake.capability_flag_bytes = u32(cap_flags_upper) << 16 | u32(cap_flags_lower)
	for c in Capabilities {
		handshake.capability_flags[c] = cap_mask(c) & handshake.capability_flag_bytes != 0
	}

	next_byte: u8
	next_byte, i, range_ok = read_byte_inc(i, buff)
	if !range_ok {
		err = .BUFFER_LENGTH
		return
	}

	if handshake.capability_flags[.CLIENT_PLUGIN_AUTH] {
		handshake.auth_plugin_data_len = next_byte
	} else if (next_byte != 0) {
		err = .EXPECTED_ZERO
		return
	}

	reserved: []u8
	reserved, i, range_ok = read_bytes_inc(i, 10, buff)
	if !range_ok {
		err = .BUFFER_LENGTH
		return
	}
	handshake.reserved = string(reserved)

	len := math.max(13, handshake.auth_plugin_data_len - 8)
	auth_data_end: []u8
	auth_data_end, i, range_ok = read_bytes_inc(i, int(len), buff)
	if !range_ok {
		err = .BUFFER_LENGTH
		return
	}

	con_slice, con_err := slice.concatenate([][]u8{auth_data_start[:], auth_data_end[:]})
	switch con_err {
	case .None:
	case .Out_Of_Memory:
		err = .CONCAT_OUT_OF_MEMORY
		return
	case .Invalid_Pointer:
		err = .CONCAT_INVALID_POINTER
		return
	case .Invalid_Argument:
		err = .CONCAT_INVALID_ARGUMENT
		return
	case .Mode_Not_Implemented:
		err = .CONCAT_MODE_NOT_IMPLEMENTED
		return
	}

	handshake.auth_plugin_data = string(con_slice)

	if handshake.capability_flags[.CLIENT_PLUGIN_AUTH] {
		auth_plugin_name: []u8
		auth_plugin_name, i, range_ok = read_null_string_inc(i, buff)
		if !range_ok {
			err = .BUFFER_LENGTH
			return
		}
		handshake.auth_plugin_name = string(auth_plugin_name)
	}

	return
}

destroy_handshake :: proc(h: ^TCP_Handshake) {
	delete(h.auth_plugin_data)
}

cap_mask :: proc(cap: Capabilities) -> u32 {
	return u32(1) << u32(cap)
}

stat_mask :: proc(stat: Status) -> u16 {
	return u16(1) << u16(stat)
}

encode_handshake_response :: proc(res: TCP_HandshakeResponse) -> (encoded_res: [dynamic]u8) {

	encoded_flags: u32

	// the encoded capability flags
	for flag, i in res.client_flags do encoded_flags |= (flag ? 1 : 0) << uint(i)
	append_u32(&encoded_res, encoded_flags)

	// the max packet size
	append_u32(&encoded_res, res.max_packet_size)

	// the character set
	append(&encoded_res, res.character_set)

	// appends 23 0s
	for i in 0 ..< 23 do append(&encoded_res, 0)

	// the null terminated username
	append_str_null(&encoded_res, res.username)


	if res.client_flags[.CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA] {
		bytes := encode_str_lenenc(res.auth_response)
		append(&encoded_res, ..bytes)
	} else {
		bytes, len := encode_str_length_u8(res.auth_response)
		append(&encoded_res, len)
		append(&encoded_res, ..bytes)
	}

	if res.client_flags[.CLIENT_CONNECT_WITH_DB] {
		append_str_null(&encoded_res, res.database)
	}

	if res.client_flags[.CLIENT_PLUGIN_AUTH] {
		append_str_null(&encoded_res, res.client_plugin_name)
	}

	if res.client_flags[.CLIENT_CONNECT_ATTRS] {
		data := encode_client_attributes(res.client_attributes)
		defer delete(data)

		append(&encoded_res, ..data)
	}

	return
}

destroy_handshake_response :: proc(h: ^TCP_HandshakeResponse) {

}



package mysql

import "core:math"

TCP_Header :: struct {
	len: int,
	seq: int,
}

TCP_Request :: struct {
	header:  TCP_Header,
	payload: []byte,
}

get_header :: proc(buff: []byte) -> (header: TCP_Header) {
	header.len = (int(buff[0]) | int(buff[1]) << 8 | int(buff[2]) << 16)
	header.seq = int(buff[3])
	return
}

encode_header :: proc(header: TCP_Header) -> (res: [4]u8) {
	res[0] = u8(header.len)
	res[1] = u8(header.len >> 8)
	res[2] = u8(header.len >> 16)
	res[3] = u8(header.seq)
	return
}

encode_request :: proc(req: TCP_Request) -> []u8 {
	res : [dynamic]u8
	header := encode_header(req.header)

	append(&res, ..header[:])
	append(&res, ..req.payload[:])

	return res[:]
}

calc_header :: proc(data: []u8, seq: int=0) -> TCP_Header {
	return {
		len(data),
		seq
	}
}

calc_request :: proc(data: []u8, seq: int=0) -> TCP_Request {
	return {
		calc_header(data, seq),
		data
	}
}

// appends a u16 to a byte array (Little Endian)
append_u16 :: proc(array: ^[dynamic]u8, val: u16) {
	append(array, u8(val), u8(val >> 8) & 0xff)
}

// append a u24 to a byte array (Little Endian)
append_u24 :: proc(array: ^[dynamic]u8, val: u32) {
	append(array, u8(val), u8(val >> 8) & 0xff, u8(val >> 16) & 0xff)
}

// appends a u32 to a byte array (Little Endian)
append_u32 :: proc(array: ^[dynamic]u8, val: u32) {
	append(array, u8(val), u8(val >> 8) & 0xff, u8(val >> 16) & 0xff, u8(val >> 24) & 0xff)
}

// appends a u64 to a byte array (Little Endian)
append_u64 :: proc(array: ^[dynamic]u8, val: u64) {
	res: [8]u8
	for i: uint = 0; i < 8; i += 1 {
		res[i] = u8(val >> (i * 8)) & 0xff
	}

	append(array, ..res[:])
}

append_str_null :: proc(array: ^[dynamic]u8, str: string) {
	append(array, ..transmute([]byte)str)
	append(array, 0)
}

append_str_lenenc :: proc(array: ^[dynamic]u8, str: string) {
	bytes := transmute([]byte)str
	len := u8(len(bytes))
}

encode_str_lenenc :: proc(str: string) -> []u8 {
	res: [dynamic]u8

	bytes := transmute([]byte)str
	len_bytes := len(bytes)

	switch {
	case len_bytes == 0:
		append(&res, 0xfb)
		return res[:]
	case len_bytes < 0xfb:
		append(&res, ..bytes)
	case len_bytes <= 0xffff:
		append(&res, 0xfc)
		append(&res, ..bytes)
	case len_bytes <= 0xffffff:
		append(&res, 0xfd)
		append(&res, ..bytes)
	case:
		append(&res, 0xfe)
		append(&res, ..bytes)
	}

	return res[:]
}

encode_str_length_u8 :: proc(str: string) -> ([]u8, u8) {
	bytes := transmute([]byte)str
	return bytes, u8(len(bytes))
}

encode_int_lenenc :: proc(val: u64) -> []u8 {
	res: [dynamic]u8

	switch {
	case val < 0xfb:
		append(&res, u8(val))
	case val <= 0xffff:
		append(&res, 0xfc)
		append_u16(&res, u16(val))
	case val <= 0xffffff:
		append(&res, 0xfd)
		append_u24(&res, u32(val))
	case:
		append(&res, 0xfe)
		append_u64(&res, val)
	}

	return res[:]
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

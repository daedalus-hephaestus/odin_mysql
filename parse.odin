package mysql

import "core:math"

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

// returns a slice of u8s from the buffer from i to i + length
// returns ok = false if i + length is outside of the buffer's range
read_bytes :: proc(i, end: int, buff: []u8) -> (res: []u8, ok: bool) {
	if end > len(buff) || i > end || i < 0 {
		ok = false
		return
	} else {
		ok = true
	}

	res = buff[i:end]
	return
}

// returns a slice of u8s from the buffer from i to i + length
// returns i + length as index
// returns ok = false if i + length is outside of the buffer's range
read_bytes_inc :: proc(i, length: int, buff: []u8) -> (res: []u8, index: int, ok: bool) {
	res, ok = read_bytes(i, i + length, buff)
	index = i + length

	return
}

// returns u8 from the buffer at i
// returns ok = false if i is outside of the buffer's range
read_byte :: proc(i: int, buff: []u8) -> (res: u8, ok: bool) {
	if i >= len(buff) || i < 0 {
		ok = false
		return
	} else {
		ok = true
	}

	res = buff[i]
	return
}

// returns u8 from the buffer at i
// returns i + 1 as index
// returns ok = false if i is outside of the buffer's range
read_byte_inc :: proc(i: int, buff: []u8) -> (res: u8, index: int, ok: bool) {
	res, ok = read_byte(i, buff)
	index = i + 1

	return
}

// returns the buffer from i until the next null
// returns ok = false if no null is found between i and the end of the buffer
read_null_string :: proc(i: int, buff: []u8) -> (res: []u8, ok: bool) {
	start := i
	index := i

	for {
		char: u8
		char, index, ok = read_byte_inc(index, buff)
		if !ok {
			return
		}

		if char == 0 {
			res, ok = read_bytes(start, index - 1, buff)
			if !ok {
				return
			}

			ok = true
			return
		}
	}
}

// returns the buffer from i until the next null
// returns i + string length as index
// returns ok = false if no null is found between i and the end of the buffer
read_null_string_inc :: proc(i: int, buff: []u8) -> (res: []u8, index: int, ok: bool) {
	start := i
	index = i

	for {
		char: u8
		char, index, ok = read_byte_inc(index, buff)
		if !ok {
			return
		}

		if char == 0 {
			res, ok = read_bytes(start, index - 1, buff)
			if !ok {
				return
			}

			ok = true
			return
		}
	}
}

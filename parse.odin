package mysql

import "core:encoding/endian"
import "core:fmt"
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

// reads a u16 from a buffer (Little Endian) at i
read_u16 :: proc(i: int, buff: []u8) -> (res: u16, ok: bool) {
	if i + 1 > len(buff) - 1 {
		ok = false
		return
	} else {
		ok = true
	}

	for j in 0 ..< 2 {
		res |= u16(buff[i + j]) << uint(8 * j)
	}
	return
}

// reads a u24 from a buffer (Little Endian) at i
read_u24 :: proc(i: int, buff: []u8) -> (res: u32, ok: bool) {
	if i + 2 > len(buff) - 1 {
		ok = false
		return
	} else {
		ok = true
	}

	for j in 0 ..< 3 {
		res |= u32(buff[i + j]) << uint(8 * j)
	}
	return
}

// reads a u32 from a buffer (Little Endian) at i
read_u32 :: proc(i: int, buff: []u8) -> (res: u32, ok: bool) {
	if i + 3 > len(buff) - 1 {
		ok = false
		return
	} else {
		ok = true
	}

	for j in 0 ..< 4 {
		res |= u32(buff[i + j]) << uint(8 * j)
	}
	return
}

// reads a u64 from a buffer (Little Endian) at i
read_u64 :: proc(i: int, buff: []u8) -> (res: u64, ok: bool) {
	if i + 7 > len(buff) - 1 {
		ok = false
		return
	} else {
		ok = true
	}

	for j in 0 ..< 8 {
		res |= u64(buff[i + j]) << uint(8 * j)
	}
	return
}

append_str_null :: proc(array: ^[dynamic]u8, str: string) {
	append(array, ..transmute([]byte)str)
	append(array, 0)
}

encode_str_lenenc :: proc(str: string) -> []u8 {
	res: [dynamic]u8

	bytes := transmute([]byte)str
	len_bytes := encode_int_lenenc(u64(len(bytes)))
	defer delete(len_bytes)

	append(&res, ..len_bytes)
	append(&res, ..bytes)

	return res[:]
}

append_str_lenenc :: proc(array: ^[dynamic]u8, str: string) {
	bytes := encode_str_lenenc(str)
	defer delete(bytes)
	append(array, ..bytes)
}

// returns a length encoded string from the buffer starting at i
// returns ok = false if i + the encoded length is outside of the buffer's range
read_str_lenenc :: proc(i: int, buff: []u8) -> (res: string, ok: bool) {
	length, index := read_int_lenenc_inc(i, buff) or_return

	if index + int(length) > len(buff) {
		return
	}

	res = string(buff[index:index + int(length)])
	ok = true

	return
}

// returns a length encoded string from the buffer starting at i
// returns ok = false if i + the encoded length is outside of the buffer's range
read_str_lenenc_inc :: proc(i: int, buff: []u8) -> (res: string, index: int, ok: bool) {
	length, str_start := read_int_lenenc_inc(i, buff) or_return

	if index + int(length) > len(buff) {
		return
	}

	res = string(buff[str_start:str_start + int(length)])
		ok = true
	index = str_start + int(length)

	return
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

append_int_lenenc :: proc(array: ^[dynamic]u8, val: u64) {
	bytes := encode_int_lenenc(val)
	defer delete(bytes)
	append(array, ..bytes)
}

// returns a length encoded u64 from the buffer starting at i
// returns ok = false if i + the encoded length is outside of the buffer's range
read_int_lenenc :: proc(i: int, buff: []u8) -> (res: u64, ok: bool) {
	if i > len(buff) - 1 {
		return
	}

	switch {
	case buff[i] < 0xfb:
		res = u64(buff[i])
		ok = true
	case buff[i] == 0xfc:
		res = u64(read_u16(i + 1, buff) or_return)
		ok = true
	case buff[i] == 0xfd:
		res = u64(read_u24(i + 1, buff) or_return)
		ok = true
	case buff[i] == 0xfe:
		res = u64(read_u64(i + 1, buff) or_return)
		ok = true
	}

	return
}

// returns a length encoded u64 from the buffer starting at i
// returns i + the encoded length as index
// returns ok = false if i + the encoded length is outside of the buffer's range
read_int_lenenc_inc :: proc(i: int, buff: []u8) -> (res: u64, index: int, ok: bool) {
	if i > len(buff) - 1 {
		return
	}

	switch {
	case buff[i] < 0xfb:
		res = u64(buff[i])
		index = i + 1	
		ok = true
	case buff[i] == 0xfc:
		res = u64(read_u16(i + 1, buff) or_return)
		index = i + 3
		ok = true
	case buff[i] == 0xfd:		
		res = u64(read_u24(i + 1, buff) or_return)
		index = i + 4
		ok = true
	case buff[i] == 0xfe:
		res = u64(read_u64(i + 1, buff) or_return)
		index = i + 8
		ok = true
	}

	return
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

encode_bit :: proc(val: Bit) -> (res: [dynamic]u8) {
	byte_count := (val.len + 7) / 8

	len_bytes := encode_int_lenenc(u64(byte_count))
	defer delete(len_bytes)
	append(&res, ..len_bytes)

	for i in 0..<val.len {
		append(&res, u8(u64(val.val) >> (i * 8)))
	}

	return	
}

append_bit :: proc(array: ^[dynamic]u8, val: Bit) {
	bytes := encode_bit(val)
	defer delete(bytes)
	append(array, ..bytes[:])
}



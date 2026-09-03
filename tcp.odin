package mysql

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


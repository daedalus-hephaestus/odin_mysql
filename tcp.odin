package mysql

import "core:encoding/endian"
import "core:fmt"
import "core:net"

PacketType :: enum {
	Undetermined,
	Handshake,
	SSLRequest,
	HandshakeResponse,
	AuthSwitchRequest,
	OldAuthSwitchRequest,
	AuthSwitchResponse,
	AuthMoreData,
	AuthNextFactor,
	OK_Packet,
	ERR_Packet,
}

MAX_PACKET_SIZE :: 0x1000000

Connection :: struct {
	state:  State,
	ip:     string,
	addr:   net.Endpoint,
	socket: net.TCP_Socket,
	buff:   [4096]u8,
	i:      int,
	n:      int,
}

PacketError :: enum {
	HEADER_LENGTH,
	PAYLOAD_LENGTH,
}

ConnectionError :: union {
	net.TCP_Recv_Error,
	net.TCP_Send_Error,
	net.Network_Error,
	PacketParseError,
	PacketError,
}

Header :: struct {
	len: int,
	seq: int,
}

Packet :: struct {
	header:  Header,
	payload: []u8,
}

read_header :: proc(buff: []byte) -> (header: Header) {
	header.len = (int(buff[0]) | int(buff[1]) << 8 | int(buff[2]) << 16)
	header.seq = int(buff[3])
	return
}

read_packet :: proc(conn: ^Connection) -> (packet: Packet) {
	packet.header = read_header(conn.buff[:4])
	packet.payload = conn.buff[4:conn.n]
	return
}

write_packet :: proc(conn: ^Connection, packet: Packet) {
	copy(conn.buff[:], encode_packet(packet))
}

encode_header :: proc(header: Header) -> (res: [4]u8) {
	return {u8(header.len), u8(header.len >> 8), u8(header.len >> 16), u8(header.seq)}
}

encode_packet :: proc(packet: Packet) -> []u8 {
	res: [dynamic]u8
	header := encode_header(packet.header)

	append(&res, ..header[:])
	append(&res, ..packet.payload[:])

	return res[:]
}

destroy_packet :: proc(packet: ^Packet) {
	delete(packet.payload)
}

get_header :: proc(data: []u8, seq: int = 0) -> Header {
	return {len(data), seq}
}

get_packet :: proc(data: []u8, seq: int = 0) -> Packet {
	return {get_header(data, seq), data[:]}
}

get_packet_type :: proc(packet: Packet) -> (type: PacketType) {
	switch packet.payload[0] {
	case 0:
		type = .OK_Packet
	case 0x1:
		type = .AuthMoreData
	case 0x2:
		type = .AuthNextFactor
	case 0xfe:
		type = .AuthSwitchRequest
	case 0xff:
		type = .ERR_Packet
	}
	return
}

init_connection :: proc(
	ip, username, password: string,
	db: string = "",
	auth_plugin: AuthPlugin = .MYSQL_NATIVE_PASSWORD,
) -> (
	conn: Connection,
	err: ConnectionError,
) {
	conn.addr = net.resolve_ip4(ip) or_return
	conn.ip = ip
	conn.socket = net.dial_tcp(conn.addr) or_return

	conn.state = .Awaiting_Handshake

	// get the initial handshake buffer
	initial_packet := recv_connection(&conn) or_return
	defer destroy_packet(&initial_packet)

	decoded_handshake := parse_handshake(initial_packet.payload) or_return
	defer destroy_handshake(&decoded_handshake)

	conn.i = initial_packet.header.seq + 1

	handshake_response: TCP_HandshakeResponse = {
		client_flags = #partial{
			.CLIENT_LONG_PASSWORD = true,
			.CLIENT_PROTOCOL_41 = true,
			.CLIENT_SECURE_CONNECTION = true,
			.CLIENT_PLUGIN_AUTH = true,
			.CLIENT_CONNECT_ATTRS = true,
			.CLIENT_SESSION_TRACK = true,
		},
		max_packet_size = MAX_PACKET_SIZE,
		character_set = decoded_handshake.character_set,
		username = username,
		database = db,
		client_plugin_name = set_auth_plugin(auth_plugin),
		client_attributes = DEFAULT_ATTRIBUTES,
	}

	if auth_plugin == get_auth_plugin(decoded_handshake) {
		auth_response := encrypt_password(
			password,
			decoded_handshake.auth_plugin_data,
			auth_plugin,
		)
		handshake_response.auth_response = string(auth_response[:])
	}

	encoded_response := encode_handshake_response(handshake_response)
	defer delete(encoded_response)

	response_packet := get_packet(encoded_response[:], conn.i)

	encoded_response_packet := encode_packet(response_packet)
	defer delete(encoded_response_packet)

	send_connection(&conn, encoded_response_packet[:]) or_return

	// get the servers response to the handshake
	handshake_response_packet := recv_connection(&conn) or_return
	defer destroy_packet(&handshake_response_packet)

	packet_type := get_packet_type(handshake_response_packet)
	#partial switch packet_type {
	case .OK_Packet:
		ok_packet, ok_err := parse_ok_packet(
			handshake_response_packet.payload[:],
			handshake_response.client_flags,
		)
		fmt.println(ok_packet)
	case .ERR_Packet:
		err_packet, err_err := parse_err_packet(
			handshake_response_packet.payload[:],
			handshake_response.client_flags,
		)
		fmt.println(err_packet)
	}

	test_com: COM_QUERY = {
		command             = 3,
		parameter_count     = 5,
		parameter_set_count = 1,
		parameters          = {
			{name = "id", value = BigUInt(15)},
			{name = "name", value = VarChar("test")},
			{name = "id", value = UInt(12)},
			{name = "name", value = nil},
			{name = "id", value = Int(12)},
		},
	}

	data, encode_err := encode_com_query(test_com, handshake_response.client_flags)
	fmt.printfln("%v", data)
	fmt.println(encode_err)
	delete(data)

	// tmp := recv_connection(&conn) or_return
	// fmt.println(tmp)
	return
}

// reads a packet from the tcp connection
recv_connection :: proc(conn: ^Connection) -> (packet: Packet, err: ConnectionError) {
	raw_payload: [dynamic]u8

	// get the first four bytes (the header)
	conn.n = net.recv_tcp(conn.socket, conn.buff[:4]) or_return

	// header malformed
	if conn.n != 4 {
		err = .HEADER_LENGTH
		return
	}

	packet.header = read_header(conn.buff[:conn.n])

	// the number of bytes read
	total := 0
	for total < packet.header.len {
		// read_n is either 4096 or the remaining packet
		read_n := total + 4096 > packet.header.len ? total + packet.header.len : 4096
		conn.n = net.recv_tcp(conn.socket, conn.buff[:read_n]) or_return

		if conn.n != read_n {
			err = .PAYLOAD_LENGTH
			return
		}

		append(&raw_payload, ..conn.buff[:conn.n])
		total += 4096
	}

	packet.payload = raw_payload[:]
	return
}

send_connection :: proc(conn: ^Connection, buff: []u8) -> (err: net.TCP_Send_Error) {
	_, err = net.send_tcp(conn.socket, buff)
	return
}

destroy_connection :: proc(conn: ^Connection) {
	delete(conn.ip)
}

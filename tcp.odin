package mysql

import "core:fmt"
import "core:net"

PacketType :: enum {
	Handshake,
	SSLRequest,
	HandshakeResponse,
	AuthSwitchRequest,
	OldAuthSwitchRequest,
	AuthSwitchResponse,
	AuthMoreData,
	AuthNextFactor,
}

ActionType :: enum {
	Read,
	Write,
	Error,
}

Action :: struct {
	type: ActionType,
	data: []u8,
}

Connection :: struct {
	state:  State,
	ip:     string,
	addr:   net.Endpoint,
	socket: net.TCP_Socket,
	buff:   [4096]u8,
	n:      int,
}

HandshakeError :: union {
	net.TCP_Recv_Error,
	HandshakeParseError,
}

Header :: struct {
	len: int,
	seq: int,
}

Packet :: struct {
	header:  Header,
	payload: []byte,
}

read_header :: proc(buff: []byte) -> (header: Header) {
	header.len = (int(buff[0]) | int(buff[1]) << 8 | int(buff[2]) << 16)
	header.seq = int(buff[3])
	return
}

read_packet :: proc(buff: []byte) -> (packet: Packet) {
	packet.header = read_header(buff)
	packet.payload = buff[4:]
	return
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

parse_header :: proc(data: []u8, seq: int = 0) -> Header {
	return {len(data), seq}
}

parse_packet :: proc(data: []u8, seq: int = 0) -> Packet {
	return {parse_header(data, seq), data[4:]}
}

init_connection :: proc(ip: string) -> (conn: Connection, err: net.Network_Error) {
	conn.addr, err = net.resolve_ip4(ip)
	conn.ip = ip
	return
}

dial_connection :: proc(conn: ^Connection) -> (err: net.Network_Error) {
	conn.socket, err = net.dial_tcp(conn.addr)
	return
}

recv_connection :: proc(conn: ^Connection) -> (err: net.TCP_Recv_Error) {
	conn.n, err = net.recv_tcp(conn.socket, conn.buff[:])
	return
}

send_connection :: proc(conn: ^Connection, buff: []u8) -> (err: net.TCP_Send_Error) {
	_, err = net.send_tcp(conn.socket, buff)
	return
}

handshake_connection :: proc(
	conn: ^Connection,
	username, password: string,
	database: string = "",
) -> (
	err: HandshakeError,
) {
	err = recv_connection(conn)
	if err != .None do return

	fmt.println("server:")
	fmt.println(conn.buff[:conn.n])

	req: Packet = {
		header  = read_header(conn.buff[:conn.n]),
		payload = conn.buff[4:conn.n],
	}

	handshake: TCP_Handshake
	handshake, err = parse_handshake(req.payload)
	defer destroy_handshake(&handshake)

	hash: [20]u8
	if get_auth_plugin(handshake) == .MYSQL_NATIVE_PASSWORD {
		hash = encrypt_native_password(password, handshake.auth_plugin_data)
	} else {
		return
	}

	response := TCP_HandshakeResponse {
		client_flags = #partial{
			.CLIENT_PROTOCOL_41 = true,
			.CLIENT_LONG_PASSWORD = true,
			.CLIENT_CONNECT_WITH_DB = len(database) > 0,
			.CLIENT_PLUGIN_AUTH = true,
			.CLIENT_SECURE_CONNECTION = true,
		},
		max_packet_size = 0x01000000,
		character_set = handshake.character_set,
		username = username,
		database = database,
		client_plugin_name = handshake.auth_plugin_name,
		auth_response = string(hash[:]),
	}
	response_bytes := encode_handshake_response(response)

	defer delete(response_bytes)

	full_response := encode_packet(parse_packet(response_bytes[:], req.header.seq + 1))
	fmt.println("client:")
	fmt.println(full_response)
	defer delete(full_response)

	send_connection(conn, full_response)
	recv_connection(conn)

	fmt.println("server:")
	fmt.println(conn.buff[:conn.n])


	return
}

destroy_connection :: proc(conn: ^Connection) {
	delete(conn.ip)
}

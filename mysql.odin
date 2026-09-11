package mysql

import "core:encoding/endian"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:net"
import "core:slice"
import "core:strings"

State :: enum {
	Awaiting_Handshake,
	Authenticating,
	Ready,
	Awaiting_result,
	Reading_result,
	Closed
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				for _, entry in track.allocation_map {
					fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
				}
			}
			if len(track.bad_free_array) > 0 {
				for entry in track.bad_free_array {
					fmt.eprintf("%v bad free at %v\n", entry.location, entry.memory)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	conn, err := init_connection("127.0.0.1:3306")
	if err != nil {
		fmt.println("resolve failed: ", err)
		return
	}

	err = dial_connection(&conn)
	if err != nil {
		fmt.println("dial failed: ", err)
		return
	}

	handshake_err := handshake_connection(&conn, "odin", "Hugin&MuginD@t@", "odin")
	fmt.println(handshake_err)
	//
	// n, rec_err := net.recv_tcp(socket, buff[:])
	// if rec_err != nil {
	// 	fmt.println("receive failed: ", rec_err)
	// 	return
	// }
	//
	// request: TCP_Request = {
	// 	header  = get_header(buff[:n]),
	// 	payload = buff[4:n],
	// }
	//
	// handshake, test_err := parse_handshake(request.payload)
	// defer destroy_handshake(&handshake)
	//
	// hash := encrypt_native_password("test", handshake.auth_plugin_data)
	// fmt.println(hash)
	//
	// response := TCP_HandshakeResponse {
	// 	client_flags = #partial{
	// 		.CLIENT_PROTOCOL_41 = true,
	// 		.CLIENT_PLUGIN_AUTH = true,
	// 		.CLIENT_LONG_PASSWORD = true,
	// 		.CLIENT_CONNECT_WITH_DB = true,
	// 	},
	// 	max_packet_size = 64,
	// 	character_set = handshake.character_set,
	// 	username = "odin",
	// 	database = "odin",
	// 	auth_response = string(hash[:]),
	// 	client_attributes = {{key = "test", value = "1235"}, {key = "hello", value = "world"}},
	// }
	//
	// encoded_response := encode_handshake_response(response)
	// defer delete(encoded_response)
	// handshake_res := calc_request(encoded_response[:], 1)
	// encoded_handshake_res := encode_request(handshake_res)
	// defer delete(encoded_handshake_res)
}

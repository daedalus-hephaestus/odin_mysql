package mysql

import "core:encoding/endian"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:net"
import "core:slice"
import "core:strings"

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

	addr, res_err := net.resolve_ip4("127.0.0.1:3306")
	if res_err != nil {
		fmt.println("resolve failed: ", res_err)
		return
	}

	socket, dial_err := net.dial_tcp(addr)
	if dial_err != nil {
		fmt.println("dial failed: ", dial_err)
		return
	}

	buff: [4096]u8

	n, rec_err := net.recv_tcp(socket, buff[:])
	if rec_err != nil {
		fmt.println("receive failed: ", rec_err)
		return
	}

	request: TCP_Request = {
		header  = get_header(buff[:n]),
		payload = buff[4:n],
	}

	handshake, test_err := parse_handshake(request.payload)
	defer destroy_handshake(&handshake)

	fmt.println(handshake)

	response := TCP_HandshakeResponse {
		client_flags = #partial{.CLIENT_PROTOCOL_41 = true},
		max_packet_size = 64,
		character_set = handshake.character_set,
		username = "odin",
		database = "odin",
		auth_response = "test",
		client_attributes = {{key = "test", value = "1235"}, {key = "hello", value = "world"}},
	}

	encoded_response := encode_handshake_response(response)
	defer delete(encoded_response)
	handshake_res := calc_request(encoded_response[:], 1)
	encoded_handshake_res := encode_request(handshake_res)
	defer delete(encoded_handshake_res)

}

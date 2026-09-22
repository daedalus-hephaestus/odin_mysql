package mysql

import "core:encoding/endian"
import "core:fmt"

ProtocolType :: enum {
	TextProtocol,
	UtilityCommand,
	PreparedStatement,
	StoredProgram,
}

QueryParameter :: struct {
	name:     string,
	value:    FieldValue,
	nil:      bool,
	unsigned: bool,
}

COM_QUERY :: struct {
	command:              u8,
	parameter_count:      u64,
	parameter_set_count:  u64,
	parameters:           []QueryParameter,
	null_bitmap:          []u8,
	new_params_bind_flag: u8,
	parameter_values:     []u8,
	query:                string,
}

encode_com_query :: proc(
	com_query: COM_QUERY,
	capabilities: [Capabilities]bool,
) -> (
	res: [dynamic]u8,
	err: PacketParseError,
) {
	append(&res, com_query.command)

	parameter_count := encode_int_lenenc(com_query.parameter_count)
	defer delete(parameter_count)
	append(&res, ..parameter_count)

	parameter_set_count := encode_int_lenenc(com_query.parameter_set_count)
	defer delete(parameter_set_count)
	append(&res, ..parameter_set_count)

	if com_query.parameter_count != u64(len(com_query.parameters)) {
		err = .PARAMETER_COUNT_MISMATCH
		return
	}

	if com_query.parameter_count > 0 {
		// the number of bytes required to store the bitmap
		null_bitmap_len := (com_query.parameter_count + 7) / 8
		for byte in 0 ..< null_bitmap_len {
			// the byte to be stored
			val: u8

			for bit in 0 ..< 8 {
				// the current parameter index
				i := u64(byte) * 8 + u64(bit)
				if i > com_query.parameter_count - 1 do break

				// if the value of the parameter is nil, place a one in its position
				if com_query.parameters[i].nil == true do val |= 1 << u8(bit)
			}
			append(&res, val)
		}

		append(&res, com_query.new_params_bind_flag)

		for p in com_query.parameters {
			type := encode_type_from_val(p.value)
			append(&res, type)
			append(&res, 0)
			append_str_lenenc(&res, p.name)
		}

		for p in com_query.parameters {
			bytes := encode_field(p.value)
			defer delete(bytes)
			append(&res, ..bytes[:])
		}
	}

	query_bytes := transmute([]u8)com_query.query
	append(&res, ..query_bytes)

	return
}

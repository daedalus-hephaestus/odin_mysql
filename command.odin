package mysql

import "core:encoding/endian"
import "core:fmt"

ProtocolType :: enum {
	TextProtocol,
	UtilityCommand,
	PreparedStatement,
	StoredProgram,
}

FieldType :: enum {
	TINYINT,
	TINYUINT,
	SMALLINT,
	SMALLUINT,
	MEDIUMINT,
	MEDIUMUINT,
	INT,
	UINT,
	BIGINT,
	BIGUINT,
	DECIMAL,
	FLOAT,
	DOUBLE,
	BIT,
	CHAR,
	VARCHAR,
	BINARY,
	VARBINARY,
	TINYBLOB,
	BLOB,
	MEDIUMBLOB,
	LONGBLOB,
	ENUM,
	DATE,
	TIME,
	DATETIME,
	TIMESTAMP,
	YEAR,
	GEOMETRY,
	POINT,
	LINESTRING,
	POLYGON,
	MULTIPOINT,
	MULTILINESTRING,
	MULTIPOLYGON,
	GEOMETRYCOLLECTION,
	JSON,
	VECTOR
}


QueryParameter :: struct {
	name: string,
	type: FieldType,
	value: any
}

COM_QUERY :: struct {
	command:              u8,
	parameter_count:      u64,
	parameter_set_count:  u64,
	null_bitmap:          []u8,
	new_params_bind_flag: u8,
	param_type_and_flag:  u16,
	parameter_name:       string,
	parameter_values:     []u8,
	query:                string,
}

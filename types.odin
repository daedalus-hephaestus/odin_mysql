package mysql

import "core:fmt"
import "core:time"

TinyInt :: distinct i8
TinyUInt :: distinct u8
SmallInt :: distinct i16
SmallUInt :: distinct u16
MediumInt :: distinct i32
MediumUInt :: distinct u32
Int :: distinct i32
UInt :: distinct u32
BigInt :: distinct i64
BigUInt :: distinct u64

Decimal :: distinct string
Numeric :: distinct string

Float :: distinct f32
Double :: distinct f64

Bit :: distinct u64

Char :: distinct string
VarChar :: distinct string

Binary :: distinct []u8
VarBinary :: distinct []u8

TinyBlob :: distinct []u8
Blob :: distinct []u8
MediumBlob :: distinct []u8
LongBlob :: distinct []u8

Enum :: distinct string

Date :: distinct time.Time
Time :: distinct time.Duration
DateTime :: distinct time.Time
TimeStamp :: distinct time.Time
Year :: distinct u16

Geometry :: distinct []u8
Point :: distinct []u8
LineString :: distinct []u8
Polygon :: distinct []u8
MultiPoint :: distinct []u8
MultiLineString :: distinct []u8
MultiPolygon :: distinct []u8
GeometryCollection :: distinct []u8

Json :: distinct string
Vector :: distinct []f32

FieldType :: enum {
	MYSQL_TYPE_DECIMAL,
	MYSQL_TYPE_TINY,
	MYSQL_TYPE_SHORT,
	MYSQL_TYPE_LONG,
	MYSQL_TYPE_FLOAT,
	MYSQL_TYPE_DOUBLE,
	MYSQL_TYPE_NULL,
	MYSQL_TYPE_TIMESTAMP,
	MYSQL_TYPE_LONGLONG,
	MYSQL_TYPE_INT24,
	MYSQL_TYPE_DATE,
	MYSQL_TYPE_TIME,
	MYSQL_TYPE_DATETIME,
	MYSQL_TYPE_YEAR,
	_MYSQL_TYPE_NEWDATE,
	MYSQL_TYPE_VARCHAR,
	MYSQL_TYPE_BIT,
	MYSQL_TYPE_TIMESTAMP2,
	_MYSQL_TYPE_DATETIME2,
	MYSQL_TYPE_TYPED_ARRAY,
	MYSQL_TYPE_VECTOR = 242,
	MYSQL_TYPE_INVALID = 243,
	MYSQL_TYPE_BOOL = 244,
	MYSQL_TYPE_JSON = 245,
	MYSQL_TYPE_NEWDECIMAL = 246,
	MYSQL_TYPE_ENUM = 247,
	MYSQL_TYPE_SET = 248,
	MYSQL_TYPE_TINY_BLOB = 249,
	MYSQL_TYPE_MEDIUM_BLOB = 250,
	MYSQL_TYPE_LONG_BLOB = 251,
	MYSQL_TYPE_BLOB = 252,
	MYSQL_TYPE_VAR_STRING = 253,
	MYSQL_TYPE_STRING = 254,
	MYSQL_TYPE_GEOMETRY = 255,
}

FieldValue :: union {
	TinyInt,
	TinyUInt,
	SmallInt,
	SmallUInt,
	MediumInt,
	MediumUInt,
	Int,
	UInt,
	BigInt,
	BigUInt,
	Decimal,
	Numeric,
	Float,
	Double,
	Bit,
	Char,
	VarChar,
	Binary,
	VarBinary,
	TinyBlob,
	MediumBlob,
	Blob,
	LongBlob,
	Enum,
	Date,
	Time,
	DateTime,
	TimeStamp,
	Year,
	Geometry,
	Point,
	LineString,
	Polygon,
	MultiPoint,
	MultiLineString,
	MultiPolygon,
	Json,
	Vector,
}

encode_field :: proc(value: FieldValue) -> (res: [dynamic]u8, ok: bool) {
	#partial switch v in value {
	case VarChar:
		append_str_lenenc(&res, string(v))
	}
	fmt.println(typeid_of(type_of(value)))
	return
}

get_field_type :: proc(value: FieldValue) -> (type: FieldType, unsigned: bool) {
	switch v in value {
	case TinyInt:
		type = .MYSQL_TYPE_TINY
	case TinyUInt:
		type, unsigned = .MYSQL_TYPE_TINY, true
	case SmallInt:
		type = .MYSQL_TYPE_SHORT
	case SmallUInt:
		type, unsigned = .MYSQL_TYPE_SHORT, true
	case MediumInt:
		type = .MYSQL_TYPE_INT24
	case MediumUInt:
		type, unsigned = .MYSQL_TYPE_INT24, true
	case Int:
		type = .MYSQL_TYPE_LONG
	case UInt:
		type, unsigned = .MYSQL_TYPE_LONG, true
	case BigInt:
		type = .MYSQL_TYPE_LONGLONG
	case BigUInt:
		type, unsigned = .MYSQL_TYPE_LONGLONG, true
	case Decimal:
		type = .MYSQL_TYPE_DECIMAL
	case Numeric:
		type = .MYSQL_TYPE_NEWDECIMAL
	case Float:
		type = .MYSQL_TYPE_FLOAT
	case Double:
		type = .MYSQL_TYPE_DOUBLE
	case Bit:
		type = .MYSQL_TYPE_BIT
	case Char, Binary:
		type = .MYSQL_TYPE_STRING
	case VarChar:
		type = .MYSQL_TYPE_VARCHAR
	case VarBinary:
		type = .MYSQL_TYPE_VAR_STRING
	case TinyBlob:
		type = .MYSQL_TYPE_TINY_BLOB
	case MediumBlob:
		type = .MYSQL_TYPE_MEDIUM_BLOB
	case Blob:
		type = .MYSQL_TYPE_BLOB
	case LongBlob:
		type = .MYSQL_TYPE_LONG_BLOB
	case Enum:
		type = .MYSQL_TYPE_ENUM
	case Date:
		type = .MYSQL_TYPE_DATE
	case Time:
		type = .MYSQL_TYPE_TIME
	case DateTime:
		type = .MYSQL_TYPE_DATETIME
	case TimeStamp:
		type = .MYSQL_TYPE_TIMESTAMP
	case Year:
		type = .MYSQL_TYPE_YEAR
	case Geometry, Point, LineString, Polygon, MultiPoint, MultiLineString, MultiPolygon:
		type = .MYSQL_TYPE_GEOMETRY
	case Json:
		type = .MYSQL_TYPE_JSON
	case Vector:
		type = .MYSQL_TYPE_VECTOR

	}
	return
}

encode_type_from_val :: proc(value: FieldValue) -> (res: u8) {
	type, unsigned := get_field_type(value)
	res = u8(type) | u8(unsigned) << 7 
	return
}

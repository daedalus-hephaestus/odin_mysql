package mysql

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

TinyBLob :: distinct []u8
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


package mysql

import "core:crypto/legacy/sha1"
import "core:fmt"

AuthPlugin :: enum {
	UNSUPPORTED_PLUGIN,
	MYSQL_NATIVE_PASSWORD,
	CACHING_SHA2_PASSWORD,
	ED25519,
}

get_auth_plugin :: proc(handshake: TCP_Handshake) -> AuthPlugin {
	switch handshake.auth_plugin_name {
	case "mysql_native_password":
		return .MYSQL_NATIVE_PASSWORD
	case "caching_sha2_password":
		return .CACHING_SHA2_PASSWORD
	case "ed25519":
		return .ED25519
	case:
		return .UNSUPPORTED_PLUGIN
	}
}

set_auth_plugin :: proc(plugin: AuthPlugin) -> string {
	switch plugin {
	case .MYSQL_NATIVE_PASSWORD:
		return "mysql_native_password"
	case .CACHING_SHA2_PASSWORD:
		return "caching_sha2_password"
	case .ED25519:
		return "ed25519"
	case .UNSUPPORTED_PLUGIN:
		return ""
	case:
		return ""
	}
}

encrypt_password :: proc(plain, auth_data: string, plugin: AuthPlugin) -> (res: [sha1.DIGEST_SIZE]u8) {
	#partial switch plugin {
	case .MYSQL_NATIVE_PASSWORD: res = encrypt_native_password(plain, auth_data)
	}
	return
}

encrypt_native_password :: proc(plain, auth_data: string) -> (res: [sha1.DIGEST_SIZE]u8) {
	stage1: [sha1.DIGEST_SIZE]u8
	stage2: [sha1.DIGEST_SIZE]u8
	digest: [sha1.DIGEST_SIZE]u8
	ctx: sha1.Context

	sha1.init(&ctx)
	plain_bytes := transmute([]u8)plain
	sha1.update(&ctx, plain_bytes)
	sha1.final(&ctx, stage1[:])

	sha1.init(&ctx)
	sha1.update(&ctx, stage1[:])
	sha1.final(&ctx, stage2[:])

	sha1.init(&ctx)
	auth_data_bytes := transmute([]u8)auth_data
	sha1.update(&ctx, auth_data_bytes[:20])
	sha1.update(&ctx, stage2[:])
	sha1.final(&ctx, digest[:])

	token: [sha1.DIGEST_SIZE]u8
	for i in 0 ..< sha1.DIGEST_SIZE {
		token[i] = stage1[i] ~ digest[i]
	}

	return token
}

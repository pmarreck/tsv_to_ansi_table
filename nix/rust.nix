{ pkgs, profile ? "release" }:
let
	lib = pkgs.lib;
	rustPkgs = if pkgs.stdenv.hostPlatform.isLinux then pkgs.pkgsStatic else pkgs;
	target = rustPkgs.stdenv.hostPlatform.rust.rustcTarget;
	nativeLibs = lib.optionalString rustPkgs.stdenv.hostPlatform.isLinux "-ldl -lpthread -lm";
	archive = "target/${target}/${profile}/libtsv_to_ansi_table.a";
in rustPkgs.rustPlatform.buildRustPackage {
	pname = "tsv-to-ansi-table-rust-${profile}";
	version = "0.1.0";
	src = lib.fileset.toSource {
		root = ../.;
		fileset = lib.fileset.unions [ ../rust ../cli ../include ../platform ../src/help.txt ../src/example-words.txt ../tests/integration/library.c ];
	};
	cargoRoot = "rust";
	buildAndTestSubdir = "rust";
	buildType = profile;
	checkType = "debug";
	cargoLock = {
		lockFile = ../rust/Cargo.lock;
		outputHashes."randomr-0.4.0" = "sha256-ixFWmP1Raenwc93I4FKx8u9mN5SDGBXzHbTB36M7vEI=";
	};
	doCheck = true;
	postCheck = ''
		$CC -std=c11 -Iinclude tests/integration/library.c ${archive} ${nativeLibs} -o "$TMPDIR/library-consumer"
		TSV_TO_ANSI_TABLE_GLYPHS=invalid "$TMPDIR/library-consumer"
	'';
	installPhase = ''
		runHook preInstall
		mkdir -p "$out/bin" "$out/lib" "$out/include"
		cp ${archive} "$out/lib/libtsv_to_ansi_table.a"
		cp include/tsv_to_ansi_table.h "$out/include/"
		$CC -std=c11 -O3 -DTSVAT_DEBUG=${if profile == "debug" then "1" else "0"} -Iinclude \
			cli/main.c platform/console.c ${archive} ${nativeLibs} -o "$out/bin/tsv-to-ansi-table-rust"
		runHook postInstall
	'';
	dontStrip = profile == "debug";
	meta = { license = lib.licenses.mit; mainProgram = "tsv-to-ansi-table-rust"; };
}

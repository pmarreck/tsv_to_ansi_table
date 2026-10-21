{
	description = "Roc TSV to terminal table renderer";
	inputs.nixpkgs.url = "github:NixOS/nixpkgs/9fbb54b33e91ee4ca368e35a78e0613c720600b3";
	inputs.performance-profiling.url = "github:pmarreck/performance_profiling/a04d62a441a5b9315e81f6277f57f7eddb9a57af";
	inputs.random = { url = "github:pmarreck/random/76ada4a2d6259569f901985b08d8d5ad10f45059"; flake = false; };
	outputs = { self, nixpkgs, performance-profiling, random }: let
		systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
		forAll = nixpkgs.lib.genAttrs systems;
		toolsFor = system: let
			pkgs = import nixpkgs { inherit system; };
			assets = {
				x86_64-linux = { name = "linux_x86_64"; hash = "b8a77b3f86607dc6dcc173d2eeb805f9f6e1314913177c50ebf73562938534b7"; };
				aarch64-linux = { name = "linux_arm64"; hash = "cfd402c6c4039d0cfea58c7d4932ccd8a4942eecb65f9a307d06514efe2e14e8"; };
				aarch64-darwin = { name = "macos_apple_silicon"; hash = "d9ff5fdd97a17bcce7b62775880ae07d1c08551020a2d2a497ce5d800bda7081"; };
			};
			asset = assets.${system};
			darwinStub = pkgs.fetchurl {
				url = "https://raw.githubusercontent.com/roc-lang/roc/2664a2788265abc62f2bde15d7ae2c6fb48ccbe8/src/cli/darwin/usr/lib/libSystem.tbd";
				hash = "sha256-T5bxQC4ZULF2SsaszQ0rnByhl7d4PKrl6Dj9CktHQCg=";
			};
			roc = pkgs.stdenvNoCC.mkDerivation {
				pname = "roc-nightly";
				version = "2026-10-12-2664a27";
				src = pkgs.fetchurl {
					url = "https://github.com/roc-lang/nightlies/releases/download/nightly-2026-10-12-2664a27/roc_nightly-${asset.name}-2026-10-12-2664a27.tar.gz";
					sha256 = asset.hash;
				};
				sourceRoot = ".";
				dontBuild = true;
				dontConfigure = true;
				dontFixup = true;
				installPhase = ''
					mkdir -p "$out/libexec/roc" "$out/bin"
					cp -r ./*/. "$out/libexec/roc/"
					mkdir -p "$out/libexec/roc/darwin/usr/lib"
					cp ${darwinStub} "$out/libexec/roc/darwin/usr/lib/libSystem.tbd"
					ln -s "$out/libexec/roc/roc" "$out/bin/roc"
				'';
			};
			unpack = name: url: hash: pkgs.runCommand name {
				src = pkgs.fetchurl { inherit url hash; };
				nativeBuildInputs = [ pkgs.zstd ];
			} ''mkdir -p "$out"; tar --zstd -xf "$src" -C "$out"'';
			basePlatform = unpack "roc-basic-cli-0.25.0"
				"https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst"
				"sha256-nAayfmca2NMH7RGN5i1rrk7vQTG57aRBSt9kOmBK1UU=";
			platform = pkgs.runCommand "tsv-roc-platform-0.25.0" {
				nativeBuildInputs = [ pkgs.zig_0_16 ];
			} ''
				cp -R ${basePlatform} "$out"
				chmod -R u+w "$out"
				cp ${./platform/Console.roc} "$out/Console.roc"
				substituteInPlace "$out/main.roc" \
					--replace-fail 'exposes [' 'exposes [Console, ' \
					--replace-fail 'hosted {' 'hosted { "tsv_console_width": Console.width!, "tsv_windows_decimal": Console.windows_decimal!,' \
					--replace-fail 'app]' '"console.o", app]' \
					--replace-fail 'app,' '"console.o", app,'
				printf '\nimport Console\n' >> "$out/main.roc"
				export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
				for pair in x64musl:x86_64-linux-musl arm64musl:aarch64-linux-musl arm64mac:aarch64-macos x64win:x86_64-windows-gnu; do
					target="''${pair%%:*}"
					zig cc -target "''${pair#*:}" -O2 -c ${./platform/console.c} -o "$out/targets/$target/console.o"
				done
			'';
			http = unpack "roc-http-1.0.0"
				"https://github.com/roc-lang/http/releases/download/1.0.0/6ZUwqYhCS8PU9Mo6MF7oV82ET2o7KYb57CLKDq4cq4sS.tar.zst"
				"sha256-6e+qlQ5y9vds326vAEJFcvppsEumEnMjV6wEU2ePArQ=";
			unicode = unpack "roc-unicode-4.2.0"
				"https://github.com/roc-lang/unicode/releases/download/4.2.0/4W8SHzvwet9hH9qZewJ1J1CVQoH7YKA6zyijWFTB3y1w.tar.zst"
				"sha256-39BST7hDY9GP1cd6y2j6HresGFvXgducKx7agTyuOik=";
		in { inherit pkgs roc platform http unicode; };
	in {
		packages = forAll (system: let
			t = toolsFor system;
			package = t.pkgs.stdenvNoCC.mkDerivation {
				pname = "tsv-to-ansi-table";
				version = "0.1.0";
				src = t.pkgs.lib.fileset.toSource {
					root = ./.;
					fileset = t.pkgs.lib.fileset.unions [ ./src ./zig ./platform ./tests ./scripts ./main.zig ./build.zig ./build.zig.zon ./test ];
				};
				strictDeps = true;
				nativeBuildInputs = [ t.roc t.pkgs.file t.pkgs.flock t.pkgs.zig_0_16 (t.pkgs.luajit.withPackages (lua: [ lua.cjson ])) t.pkgs.jq ];
				ROC_PLATFORM = t.platform;
				ROC_HTTP = t.http;
				ROC_UNICODE = t.unicode;
				RANDOM_SRC = random;
				UTF8PROC_SRC = t.pkgs.utf8proc.src;
				TSV_ROC_ENV = "1";
				buildPhase = ''
					export HOME="$TMPDIR/home" XDG_CACHE_HOME="$TMPDIR/cache"
					mkdir -p "$HOME"
					export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global" ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local"
					patchShebangs scripts test tests
					bash scripts/build-native "$out"
				'';
				doCheck = true;
				checkPhase = ''TSV_TEST_BIN="$out/bin" bash ./test'';
				dontInstall = true;
				meta = { license = t.pkgs.lib.licenses.mit; mainProgram = "tsv-to-ansi-table"; };
			};
			cross = target: rocTarget: package.overrideAttrs {
				pname = "tsv-to-ansi-table-${target}";
				buildPhase = ''
					export HOME="$TMPDIR/home" XDG_CACHE_HOME="$TMPDIR/cache"
					export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global" ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local"
					mkdir -p "$HOME" "$out/bin"
					mkdir -p "$out/share/licenses/random"
					cp "$RANDOM_SRC/LICENSE" "$out/share/licenses/random/LICENSE"
					patchShebangs scripts
					${t.pkgs.lib.optionalString (rocTarget != null) ''
						scripts/roc-env build src/main.roc --opt=speed --target=${rocTarget} --output="$out/bin/tsv-to-ansi-table-roc${t.pkgs.lib.optionalString (t.pkgs.lib.hasInfix "windows" target) ".exe"}"
					''}
					unset NIX_CFLAGS_COMPILE NIX_LDFLAGS
					scripts/zig-env build -Dutf8proc="$UTF8PROC_SRC" -Doptimize=ReleaseFast -Dtarget=${target} --prefix "$out" -j4
				'';
				# Cross builds establish compilation/linking; native suites run in default.
				doCheck = false;
				dontFixup = true;
			};
		in {
			default = package;
			linux-arm64 = cross "aarch64-linux-musl" "arm64musl";
			macos-arm64 = cross "aarch64-macos" "arm64mac";
			# The pinned Roc Windows host omits required CRT import libraries.
			windows-x86_64 = cross "x86_64-windows-gnu" null;
			windows-arm64 = cross "aarch64-windows-gnu" null;
			debug = package.overrideAttrs {
				pname = "tsv-to-ansi-table-debug";
				TSV_PROFILE = "Debug";
				checkPhase = ''bash tests/cli/debug "$out/bin/tsv-to-ansi-table-roc" "$out/bin/tsv-to-ansi-table-zig"'';
			};
		});
		checks = forAll (system: { package = self.packages.${system}.default; });
		devShells = forAll (system: let t = toolsFor system; in {
			default = t.pkgs.mkShell {
				packages = [ t.roc (t.pkgs.luajit.withPackages (lua: [ lua.cjson ])) t.pkgs.jq t.pkgs.file t.pkgs.zig_0_16 t.pkgs.flock performance-profiling.packages.${system}.default ];
				TSV_ROC_ENV = "1";
				ROC_PLATFORM = t.platform;
				ROC_HTTP = t.http;
				ROC_UNICODE = t.unicode;
				RANDOM_SRC = random;
				UTF8PROC_SRC = t.pkgs.utf8proc.src;
			};
		});
	};
}

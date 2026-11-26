{
  description = "Custom Neovim setup with Nix";
           	
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      svlangserver = pkgs.buildNpmPackage rec {
        pname = "svlangserver";
        version = "0.4.1"; # check npm for latest: npm view @imc-trading/svlangserver version
        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/@imc-trading/svlangserver/-/svlangserver-${version}.tgz";
          hash = "sha256-j0gX/6y60uQMSZnqlPWYxp10isP8pykk5crfr3jmKJw="; # nix will complain and give correct hash on first build
        };

      postPatch = ''
          cp ${./svlangserver-package-lock.json} ./package-lock.json
        '';

        # First `nix build` will fail with a hash mismatch for npmDepsHash — paste it in below.
      npmDepsHash = "sha256-gmL6pnYxwNnVdagxIwqzBjRB5QEJ2CLf1BxcATKU7Ag=";
      dontNpmBuild = true;
        installPhase = ''
          runHook preInstall
          mkdir -p $out/lib/node_modules/${pname}
          cp -r . $out/lib/node_modules/${pname}
          mkdir -p $out/bin
          chmod +x $out/lib/node_modules/${pname}/bin/main.js
          ln -s $out/lib/node_modules/${pname}/bin/main.js $out/bin/svlangserver
          runHook postInstall
        '';
      };

      language-server-bitbake = pkgs.buildNpmPackage rec {
        pname = "language-server-bitbake";
        version = "2.9.0";

        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/language-server-bitbake/-/language-server-bitbake-${version}.tgz";
          hash = "sha512-LMNCcDTXqLjvxeKus8rZg5hTVaVGO+9eRTSIoNKS34y650RC6EQbijFxL4zCr0T/n/Y3rY4zRdn9Y3DFEkzwnw==";
        };

	postPatch = ''
	  cp ${./lsb-package.json} ./package.json
	  cp ${./lsb-package-lock.json} ./package-lock.json
	'';
        
	# First `nix build` will fail with a mismatch and print the correct
        # hash to paste here.
        npmDepsHash = "sha256-vAJaAP+Yx0Zx3y/srWqq3ocie7kCJmsRB6e8QpSpiWk=";

        dontNpmBuild = true;

        installPhase = ''
          runHook preInstall
          mkdir -p $out/lib/node_modules/${pname}
          cp -r . $out/lib/node_modules/${pname}
          mkdir -p $out/bin
          ln -s $out/lib/node_modules/${pname}/out/server.js $out/bin/language-server-bitbake
          chmod +x $out/bin/language-server-bitbake
          runHook postInstall
        '';
      };

      # `vhd` command: generates vhdl_ls.toml for the current directory
      vhd = pkgs.writeScriptBin "vhd" ''
        #!${pkgs.python3}/bin/python3
        ${builtins.readFile ./tools/vhd.py}
      '';

      plugins = with pkgs.vimPlugins; [
        localPlugins
        nightfox-nvim
        nvim-lspconfig
        nvim-cmp
        cmp-nvim-lsp
        cmp-buffer
        cmp-path
        luasnip
	nvim-lint
        (nvim-treesitter.withPlugins (p: [
          p.c p.cpp p.python p.bash p.json p.yaml p.lua p.vhdl p.systemverilog
        ]))
        plenary-nvim     # required dependency of telescope
        telescope-nvim
        lualine-nvim
        vim-fugitive
        vim-commentary
	bitbake
      ];

      extraPackages = with pkgs; [
        lazygit
        shellcheck
        xdg-utils
        clang-tools
        cscope
        pyright
        gdb
	oelint-adv
	vhdl-ls
	vhd
	verilator
        svlangserver
        lua-language-server
        bash-language-server
        yaml-language-server
	cmake-language-server
	docker-language-server
	systemd-language-server
	language-server-bitbake
      ];

      customNeovim = pkgs.neovim.override {
        configure = {
	  customRC = ''
            lua << EOF
            ${builtins.readFile ./init.lua}
            EOF
          '';
          packages.myPlugins.start = plugins;
        };
      };

    nvimEnv = pkgs.symlinkJoin {
        name = "nix-nvim";
  	paths = [ customNeovim ];
  	buildInputs = [ pkgs.makeWrapper ];
  	postBuild = ''
    	wrapProgram $out/bin/nvim \
      	--prefix PATH : ${pkgs.lib.makeBinPath extraPackages}
	'';
    };

    localPlugins = pkgs.stdenv.mkDerivation {
        name = "local-nvim-plugins";
        src = ./lua;
        installPhase = ''
        mkdir -p $out/lua
        cp *.lua $out/lua/
        '';
    };

    in {
      packages.${system}.default = nvimEnv;

      apps.${system}.default = {
        type = "app";
        program = "${nvimEnv}/bin/nvim";
      };
    };
}

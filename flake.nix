{
  description = "My flakes configuration";

  outputs =inputs@{ self, nixpkgs }:
    let
      # --- SYSTEM SETTINGS --- #
	systemSettings = {
	  system = "x86_64-linux";
	  hostname = "nixos";
	  profile = "personal";
 	  timezone = "America/Los_Angeles";
	  locale = "en_US.UTF-8";
	  bootMode = "bios"; #uefi or bios
	  #bootMountPath = "/dev/vda" #only for uefi boot
	  grubDevice = "/dev/vda"; # only for bios mode
          gpuType = "amd";
	};

      # --- USER SETTINGS --- #
	userSettings = rec {
	  username = "sky";
	  name = "Skylar";
	  email = "skylarkass@protonmail.com";
	  dotfilesDir = "~/.dotfiles";
	  theme = "io"; # from themes directory ./themes/
	  wm = "hyprland"; #must select in ./user/wm and ./system/wm/
	  #window manager type (wayland or x11) translator
	  wmType = if ( wm == "hyprland" ) then "wayland" else "x11";
	  browser = "librewolf"; #select one from ./user/app/browser
	  term = "alacritty";
	  font = "Intel One Mono";
	  fontPkg = pkgs.intel-one-mono;
	};

        # create patched nixpkgs
        nixpkgs-patched =
          (import inputs.nixpkgs { system = systemSettings.system; rocmSupport = (if systemSettings.gpu == "amd" then true else false); }).applyPatches {
           name = "nixpkgs-patched";
           src = inputs.nixpkgs;
         # patches = [ ./patches/emacs-no-version-check.patch ];
        };

	# Configure pkgs
	# nixpkgs for server
	# otherwise use nixpkgs-unstable
	pkgs = (if (systemSettings.profile == "homelab")
      		then
                  pkgs-stable
              	else
                  (import inputs.nixpkgs-patched {
                    system = systemSettings.system;
                    config = {
                      allowUnfree = true;
                      allowUnfreePredicate = (_: true);
                    };
                    overlays = [ inputs.rust-overlay.overlays.default ];
                  }));

      	pkgs-stable = import inputs.nixpkgs-stable {
          system = systemSettings.system;
          config = {
            allowUnfree = true;
            allowUnfreePredicate = (_: true);
          };
        };

      	pkgs-unstable = import inputs.nixpkgs-patched {
          system = systemSettings.system;
          config = {
            allowUnfree = true;
            allowUnfreePredicate = (_: true);
          };
          overlays = [ inputs.rust-overlay.overlays.default ];
        };

#        pkgs-kdenlive = import inputs.kdenlive-pin-nixpkgs {
#          system = systemSettings.system;
#        };

        pkgs-nwg-dock-hyprland = import inputs.nwg-dock-hyprland-pin-nixpkgs {
          system = systemSettings.system;
        };

	# configure lib
        # use nixpkgs if running a server (homelab or worklab profile)
        # otherwise use patched nixos-unstable nixpkgs
        lib = (if (systemSettings.profile == "homelab")
               then
                 inputs.nixpkgs-stable.lib
               else
                 inputs.nixpkgs.lib);

      # use home-manager-stable if running a server (homelab or worklab profile)
      # otherwise use home-manager-unstable
        home-manager = (if (systemSettings.profile == "homelab")
               then
                 inputs.home-manager-stable
               else
                 inputs.home-manager-unstable);	

	 # Systems that can run tests:
        supportedSystems = [ "aarch64-linux" "i686-linux" "x86_64-linux" ];

      # Function to generate a set based on supported systems:
        forAllSystems = inputs.nixpkgs.lib.genAttrs supportedSystems;

      # Attribute set of nixpkgs for each system:
        nixpkgsFor =
          forAllSystems (system: import inputs.nixpkgs { inherit system; });	
  
     in {
        homeConfigurations = {
          user = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              (./. + "/profiles" + ("/" + systemSettings.profile) + "/home.nix") # load home.nix from selected PROFILE
            ];
            extraSpecialArgs = {
              # pass config variables from above
              inherit pkgs-stable;
              inherit pkgs-nwg-dock-hyprland;
              inherit systemSettings;
              inherit userSettings;
              inherit inputs;
            };
          };
        }; 
	nixosConfigurations = {
          system = lib.nixosSystem {
            system = systemSettings.system;
            modules = [
              (./. + "/profiles" + ("/" + systemSettings.profile) + "/configuration.nix")
            ]; # load configuration.nix from selected PROFILE
            specialArgs = {
              # pass config variables from above
              inherit pkgs-stable;
              inherit systemSettings;
              inherit userSettings;
              inherit inputs;
            };
          };
        };
# 	nixOnDroidConfigurations = {
#          inherit pkgs;
#          default = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
#            modules = [ ./profiles/nix-on-droid/configuration.nix ];
#          };
#          extraSpecialArgs = {
#            # pass config variables from above
#            inherit pkgs-stable;
#            inherit systemSettings;
#            inherit userSettings;
#            inherit inputs;
#          };
#        };

#        packages = forAllSystems (system:
#          let pkgs = nixpkgsFor.${system};
#          in {
#            default = self.packages.${system}.install;
#
#            install = pkgs.writeShellApplication {
#              name = "install";
#              runtimeInputs = with pkgs; [ git ]; # I could make this fancier by adding other deps
#              text = ''${./install.sh} "$@"'';
#            };
#          });

#        apps = forAllSystems (system: {
#          default = self.apps.${system}.install;

#          install = {
#            type = "app";
#            program = "${self.packages.${system}.install}/bin/install";
#          };
#        });
      };   
   inputs = {
      nixpkgs.url = "nixpkgs/nixos-unstable";
      nixpkgs-stable.url = "nixpkgs/nixos-24.05";
      nwg-dock-hyprland-pin-nixpkgs.url = "nixpkgs/2098d845d76f8a21ae4fe12ed7c7df49098d3f15";

      home-manager-unstable.url = "github:nix-community/home-manager/master";
      home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs";

      home-manager-stable.url = "github:nix-community/home-manager/release-24.05";
      home-manager-stable.inputs.nixpkgs.follows = "nixpkgs-stable";

      nix-on-droid = {
        url = "github:nix-community/nix-on-droid/master";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.home-manager.follows = "home-manager-unstable";
      };

      hyprland = {
        type = "git";
        url = "https://github.com/hyprwm/Hyprland";
        submodules = true;
        rev = "918d8340afd652b011b937d29d5eea0be08467f5";
      };
      hyprland.inputs.nixpkgs.follows = "nixpkgs";
      hyprland-plugins.url = "github:hyprwm/hyprland-plugins/3ae670253a5a3ae1e3a3104fb732a8c990a31487";
      hyprland-plugins.inputs.hyprland.follows = "hyprland";
   #   hycov.url = "github:DreamMaoMao/hycov/de15cdd6bf2e46cbc69735307f340b57e2ce3dd0";
    #  hycov.inputs.hyprland.follows = "hyprland";
     # hyprgrass.url = "github:horriblename/hyprgrass/736119f828eecaed2deaae1d6ff1f50d6dabaaba";
    #  hyprgrass.inputs.hyprland.follows = "hyprland";

      stylix.url = "github:danth/stylix";

      rust-overlay.url = "github:oxalica/rust-overlay";
  };
}

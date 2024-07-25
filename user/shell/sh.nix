{ pkgs, ... }:
let

	#My shell aliases
	myAliases = {
	};
      in
      {
	programs.bash = {
	  enable = true;
	  enableCompletion = true;
	  shellAliases = myAliases;
	};

	home.packages = with pkgs; [
	  disfetch  onefetch lolcat cowsay neofetch
	  gnugrep gnused
	  bat eza bottom fd bc
	  direnv nix-direnv
	];

	programs.direnv.enable = truel
	programs.direnv.enableZshIntegration = true;
	programs.direnv.nix-direnv.enable = true;
      }

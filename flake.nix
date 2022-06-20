{
  description = "A kube config chooser in bash";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-21.05";

  outputs = { self, nixpkgs }:
    let

      # to work with older version of flakes
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = builtins.substring 0 8 lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

    in

    {

      # A Nixpkgs overlay.
      overlay = final: prev: {

        kube = with final; stdenv.mkDerivation rec {
          name = "kube-${version}";

          unpackPhase = ":";

          buildPhase =
            ''
              cat > kube <<EOF
              #! $SHELL
              
              echo "test"
              export KUBE_CONFIG=\`ls ~/.kube/*.yaml | ${nixpkgsFor.${system}.fzf}/bin/fzf\`
              echo \$KUBE_CONFIG
              ${nixpkgsFor.${system}.k9s}/bin/k9s --kubeconfig \$KUBE_CONFIG
              EOF
              chmod +x kube
            '';

          installPhase =
            ''
              mkdir -p $out/bin
              cp kube $out/bin/
            '';
        };

      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) kube;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.kube);

      # A NixOS module, if applicable (e.g. if the package provides a system service).
      nixosModules.kube =
        { pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlay ];

          environment.systemPackages = [ pkgs.kube ];

          #systemd.services = { ... };
        };


    };
}

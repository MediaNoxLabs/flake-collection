{
  perSystem =
    { pkgs, ... }:
    {
      # nixfmt-tree is the treefmt-backed wrapper that `nix fmt` invokes bare
      # to format every .nix in the tree (raw `nixfmt` would read stdin and
      # fail when called with no args).
      formatter = pkgs.nixfmt-tree;

      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt
          git
        ];
      };
    };
}

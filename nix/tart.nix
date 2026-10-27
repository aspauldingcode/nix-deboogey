{ pkgs }:

pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "tart";
  version = "2.41.1";

  src = pkgs.fetchurl {
    url = "https://github.com/openai/tart/releases/download/${finalAttrs.version}/tart.tar.gz";
    hash = "sha256-5oCnNP68z859TpEMH38T/DsA8ZoYHJReLXRt4yFMMsI=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin"
    tar -xzf "$src" -C "$out/Applications"
    ln -s "$out/Applications/tart.app/Contents/MacOS/tart" "$out/bin/tart"
    runHook postInstall
  '';

  meta.platforms = [ "aarch64-darwin" "x86_64-darwin" ];
})

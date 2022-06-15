final: prev: let
  addNativeBuildInputs = drvName: inputs: {
    "${drvName}" = prev.${drvName}.overridePythonAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ inputs;
    });
  };
in
  {
    # Leaving this behind for review but it caused errors during build.
    # error: builder for '/nix/store/9d99vpmfy3nrx7mbdkccbfl9n68n5vs9-python3.9-ipykernel-6.14.0.drv' failed with exit code 2;
    #   > sed: can't read setup.py: No such file or directory
    # ipykernel = prev.ipykernel.overridePythonAttrs (old: {
    #   postPatch = ''
    #     sed -i "/debugpy/d" setup.py
    #   '';
    # });

    ipykernel = prev.ipykernel.overridePythonAttrs (old: {
      postPatch = ''
        # remove custom install
        sed -i "s/cmdclass={'install': install_with_kernelspec},//" setup.py
      '';
    });
  }
  // addNativeBuildInputs "jsonschema" [final.hatchling final.hatch-vcs]
  // addNativeBuildInputs "traitlets" [final.hatchling]
  // addNativeBuildInputs "terminado" [final.hatchling]
  // addNativeBuildInputs "jupyter-client" [final.hatchling]
  // addNativeBuildInputs "ipykernel" [final.hatchling]

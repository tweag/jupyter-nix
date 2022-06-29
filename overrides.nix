final: prev: let
  addNativeBuildInputs = drvName: inputs: {
    "${drvName}" = prev.${drvName}.overridePythonAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ inputs;
    });
  };
in
  {}
  // addNativeBuildInputs "jsonschema" [final.hatchling final.hatch-vcs]
  // addNativeBuildInputs "traitlets" [final.hatchling]
  // addNativeBuildInputs "terminado" [final.hatchling]
  // addNativeBuildInputs "jupyter-server" [final.hatchling]
  // addNativeBuildInputs "jupyterlab-server" [final.hatchling]
  // addNativeBuildInputs "ipykernel" [final.hatchling]
  // {
    jupyter-client = prev.jupyter-client.overridePythonAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [final.hatchling];
      postPatch = ''
        # default the native kernel to False so it does not appear in the env
        sed -i \
          -e "/ensure_native_kernel = Bool(/!b;n;c\        False," \
          jupyter_client/kernelspec.py
      '';
    });
    jupyter-core = prev.jupyter-core.overridePythonAttrs (old: {
      postPatch = ''
        # remove system paths from jupyter paths
        sed -i \
          -e '/paths.extend(SYSTEM_JUPYTER_PATH)/d' \
          -e '/paths.extend(SYSTEM_CONFIG_PATH)/d' \
            ./jupyter_core/paths.py
        sed -i -E 's/(ENV_JUPYTER_PATH = )(\[.*\])/\1[]/g' ./jupyter_core/paths.py
        sed -i -E 's/(ENV_CONFIG_PATH = )(\[.*\])/\1[]/g' ./jupyter_core/paths.py
      '';
    });
  }

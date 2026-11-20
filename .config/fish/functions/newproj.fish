function newproj --description 'Create a Python project set up for geospatial work'
    argparse h/help no-geo -- $argv
    or return 2

    if set -q _flag_help; or test (count $argv) -ne 1
        echo 'Usage: newproj [--no-geo] NAME'
        echo
        echo 'Creates NAME/ as a uv-managed Python package with pytest, Ruff, BasedPyright'
        echo 'and ipykernel, plus GeoPandas, Rasterio, Shapely and pyproj unless --no-geo.'
        echo 'Adds the editor settings from ~/.config/nvim/examples, a direnv .envrc, a'
        echo 'starter test and a Jupyter kernel named after the project, then cds into it.'
        set -q _flag_help; and return 0; or return 2
    end

    set -l name $argv[1]
    if test -e $name
        echo "newproj: $name already exists" >&2
        return 1
    end
    for tool in uv git
        if not command -q $tool
            echo "newproj: $tool is required" >&2
            return 1
        end
    end

    set -l config_home ~/.config
    set -q XDG_CONFIG_HOME; and set config_home $XDG_CONFIG_HOME
    set -l examples $config_home/nvim/examples

    # A src/ layout package; uv also runs `git init`.
    uv init --quiet --package $name; or return
    cd $name; or return

    uv add --quiet --dev basedpyright pytest ruff ipykernel; or return
    if not set -q _flag_no_geo
        uv add --quiet geopandas rasterio shapely pyproj; or return
    end

    # BasedPyright, Ruff and pytest settings shared with the Neovim configuration.
    if test -f $examples/pyproject.toml
        echo >>pyproject.toml
        sed -n '/^\[tool\./,$p' $examples/pyproject.toml >>pyproject.toml
    end

    # Same normalisation uv uses for the package's import name.
    set -l module (string lower -- $name | string replace -ar -- '[-.]' _)
    mkdir -p data outputs tests
    printf 'import %s\n\n\ndef test_import():\n    assert %s.__name__ == "%s"\n' $module $module $module >tests/test_import.py
    printf '%s\n' '' '# Local data, outputs and private settings' data/ outputs/ .env >>.gitignore

    # Activate .venv on cd (and load .env) with direnv.
    if test -f $examples/.envrc
        cp $examples/.envrc .envrc
        command -q direnv; and direnv allow .
    end

    # A Jupyter kernel running in this project's environment, for Molten.
    set -l kernel (string lower -- $name)
    uv run --quiet python -m ipykernel install --user --name $kernel --display-name $name >/dev/null; or return

    echo "Created $name. Run the tests with `uv run pytest`; in Neovim, start Molten with :MoltenInit $kernel"
end

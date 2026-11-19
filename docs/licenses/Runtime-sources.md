# OriDrug browser runtime and demonstration data

The original workbench runs locally in a Web Worker. This release ships Pyodide 0.27.7, Python 3.12.7, SQLite, OpenSSL 1.1.1w and the project-specific first-party workbench. The bundled Pyodide lock records the exact download hashes for the SQLite, SSL and OpenSSL binaries.

- Pyodide 0.27.7, Mozilla Public License 2.0. [Source for the distributed version](https://github.com/pyodide/pyodide/tree/0.27.7) and [license](./Pyodide-0.27.7.txt).
- CPython 3.12.7 including the Python standard library and standard extension modules. [Source](https://github.com/python/cpython/tree/v3.12.7) and [license and attributions](./CPython-3.12.7.txt).
- Emscripten 3.1.58 and its runtime, MIT or University of Illinois/NCSA. [Source](https://github.com/emscripten-core/emscripten/tree/3.1.58) and [license](./Emscripten-3.1.58.txt).
- OpenSSL 1.1.1w. This product includes software developed by the OpenSSL Project for use in the OpenSSL Toolkit (https://www.openssl.org/). This product includes cryptographic software written by Eric Young and software written by Tim Hudson. [Source](https://github.com/openssl/openssl/tree/OpenSSL_1_1_1w) and [license](./OpenSSL-1.1.1w.txt).
- SQLite is dedicated to the public domain by its authors. [Official dedication](https://sqlite.org/copyright.html).
- The separate workbench archive includes original license texts for its copies of Django, asgiref and sqlparse, the docking example under Apache-2.0, and attributions in data/admet/README.md and data/references/README.md.
- RCSB PDB experimental structures 2HYY and 1M17 are provided under the [wwPDB CC0 policy](https://www.wwpdb.org/about/usage-policies). The P00533 AlphaFold DB model is © DeepMind Technologies Limited, distributed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) via [Google DeepMind and EMBL-EBI](https://alphafold.ebi.ac.uk/entry/P00533).
- Therapeutics Data Commons data snapshots for DILI and half-life come from the [TDC Harvard Dataverse deposit](https://doi.org/10.7910/DVN/21LKWG). Attribution and individual snapshot hashes accompany the data in the archive.
- The RDKit distribution includes [source metadata](../science/source.json) and the [RDKit license](../science/LICENSE.txt). The Inter and Noto Sans SC font licenses and [UI package notices](./UI-packages.txt) are provided alongside this file.


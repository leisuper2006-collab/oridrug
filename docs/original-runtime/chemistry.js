/* Molecular records use the upstream RDKit MinimalLib compiled for WebAssembly. */
'use strict';

function defineChemistry(library) {
  function withMolecule(smiles, action) {
    const mol = library.get_mol(smiles, JSON.stringify({ parseName: false, allowCXSMILES: false }));
    if (!mol || !mol.is_valid()) {
      if (mol) mol.delete();
      return null;
    }
    try {
      return action(mol);
    } finally {
      mol.delete();
    }
  }
  return {
    version: library.version(),
    describe(smiles) {
      return withMolecule(smiles, mol => {
        const desc = JSON.parse(mol.get_descriptors());
        const data = JSON.parse(mol.get_json());
        const atoms = data.molecules[0].atoms;
        const defaults = data.defaults.atom;
        const counts = {};
        let charge = 0;
        for (const atom of atoms) {
          const z = atom.z ?? defaults.z;
          counts[z] = (counts[z] || 0) + 1;
          const hydrogens = atom.impHs ?? defaults.impHs;
          if (hydrogens) counts[1] = (counts[1] || 0) + hydrogens;
          charge += atom.chg ?? defaults.chg;
        }
        return JSON.stringify({ canonical: mol.get_smiles(), atoms: mol.get_num_atoms(),
          heavy: desc.NumHeavyAtoms, weight: desc.amw, logp: desc.CrippenClogP,
          counts, charge });
      });
    },
    image(smiles) {
      return withMolecule(smiles, mol => {
        const canvas = new OffscreenCanvas(440, 284);
        mol.draw_to_canvas_with_highlights(canvas, JSON.stringify({width:440,height:284,kekulize:false}));
        return new Uint8Array(canvas.getContext('2d').getImageData(0,0,440,284).data.buffer);
      });
    },
    fingerprint(smiles, radius, bits, chirality) {
      return withMolecule(smiles, mol => mol.get_morgan_fp_as_uint8array(JSON.stringify({
        radius, nBits: bits, useChirality: chirality, includeChirality: chirality
      })));
    }
  };
}

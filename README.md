[![Main Test](https://github.com/GMUCERG/TinyJAMBU-SCA/workflows/Main%20Test/badge.svg?branch=master)](https://github.com/GMUCERG/TinyJAMBU-SCA/actions)
# Masked implementation of TinyJAMBU
This is a side-channel protected hardware implementation of [TinyJAMBU AEAD](https://csrc.nist.gov/CSRC/media/Projects/lightweight-cryptography/documents/finalist-round/updated-spec-doc/tinyjambu-spec-final.pdf), developed by Sammy Lin and Abubakr Abdulgadir.

The implementation uses Domain-oriented Masking (DOM).
The design is coded in VHDL hardware description language, and utilizes the latest version of GMU's [LWC Hardware API Development Package](https://github.com/GMUCERG/LWC).

Please see the accompanying [documentation](./docs/documentation.pdf) for further information.

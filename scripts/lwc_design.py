"""LwcDesign"""
from typing import Dict, Literal, Optional, Sequence

from xeda import Design
from xeda.dataclass import Extra, Field, XedaBaseModel as BaseModel


class Lwc(BaseModel):
    """design.lwc"""

    class Aead(BaseModel):
        class InputSequence(BaseModel):
            encrypt: Optional[Sequence[Literal["ad", "pt", "npub", "tag"]]] = Field(
                ["npub", "ad", "pt", "tag"],
                description="Sequence of inputs during encryption",
            )
            decrypt: Optional[Sequence[Literal["ad", "ct", "npub", "tag"]]] = Field(
                ["npub", "ad", "ct", "tag"],
                description="Sequence of inputs during decryption",
            )

        algorithm: Optional[str] = Field(
            None,
            description="Name of the implemented AEAD algorithm based on [SUPERCOP](https://bench.cr.yp.to/primitives-aead.html) convention",
            examples=["giftcofb128v1", "romulusn1v12", "gimli24v1"],
        )
        key_bits: Optional[int] = Field(description="Size of key in bits.")
        npub_bits: Optional[int] = Field(description="Size of public nonce in bits.")
        tag_bits: Optional[int] = Field(description="Size of tag in bits.")
        input_sequence: Optional[InputSequence] = Field(
            None,
            description="Order in which different input segment types should be fed to PDI.",
        )
        key_reuse: bool = False

    class Hash(BaseModel):
        algorithm: str = Field(
            description="Name of the hashing algorithm based on [SUPERCOP](https://bench.cr.yp.to/primitives-aead.html) convention. Empty string if hashing is not supported",
            examples=["", "gimli24v1"],
        )
        digest_bits: Optional[int] = Field(
            description="Size of hash digest (output) in bits."
        )

    class Ports(BaseModel):
        class Pdi(BaseModel):
            bit_width: Optional[int] = Field(
                32,
                ge=8,
                le=32,
                description="Width of each word of PDI data in bits (`w`). The width of 'pdi_data' signal would be `pdi.bit_width × pdi.num_shares` (`w × n`) bits.",
            )
            num_shares: int = Field(1, description="Number of PDI shares (`n`)")

        class Sdi(BaseModel):
            bit_width: Optional[int] = Field(
                32,
                ge=8,
                le=32,
                description="Width of each word of SDI data in bits (`sw`). The width of `sdi_data` signal would be `sdi.bit_width × sdi.num_shares` (`sw × sn`) bits.",
            )
            num_shares: int = Field(1, description="Number of SDI shares (`sn`)")

        class Rdi(BaseModel):
            bit_width: int = Field(
                0,
                ge=0,
                le=2048,
                description="Width of the `rdi` port in bits (`rw`), 0 if the port is not used.",
            )

        pdi: Pdi = Field(description="Public Data Input port")
        sdi: Sdi = Field(description="Secret Data Input port")
        rdi: Optional[Rdi] = Field(None, description="Random Data Input port.")

    class ScaProtection(BaseModel):
        class Config:
            extra = Extra.allow

        target: Optional[Sequence[str]] = Field(
            None,
            description="Type of side-channel analysis attack(s) against which this design is assumed to be secure.",
            examples=[["spa", "dpa", "cpa", "timing"], ["dpa", "sifa", "dfia"]],
        )
        masking_schemes: Optional[Sequence[str]] = Field(
            [],
            description='Masking scheme(s) applied in this implementation. Could be name/abbreviation of established schemes (e.g., "DOM", "TI") or reference to a publication.',
            examples=[["TI"], ["DOM", "https://eprint.iacr.org/2022/000.pdf"]],
        )
        order: int = Field(
            ..., description="Claimed order of protectcion. 0 means unprotected."
        )
        notes: Optional[Sequence[str]] = Field(
            [],
            description="Additional notes or comments on the claimed SCA protection.",
        )

    aead: Optional[Aead] = Field(
        None, description="Details about the AEAD scheme and its implementation"
    )
    hash: Optional[Hash] = None
    ports: Ports = Field(description="Description of LWC ports.")
    sca_protection: Optional[ScaProtection] = Field(
        None, description="Implemented countermeasures against side-channel attacks."
    )
    block_size: Dict[str, int] = Field({"xt": 128, "ad": 128, "hm": 128})


class LwcDesign(Design):
    """A Lightweight Cryptography hardware implementations"""

    lwc: Lwc

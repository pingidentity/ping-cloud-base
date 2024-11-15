import base64
from datetime import datetime, timedelta, timezone

from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa


def sanitize_cert(cert: str):
    return base64.b64encode(bytearray(cert.strip() + "\n", "utf-8")).decode("utf-8")


def decode_cert(cert: str):
    return str(base64.b64decode(cert).decode("utf-8"))


def create_self_signed_cert(common_name: str = "*.ping-demo.com"):
    # Generate key
    key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
        backend=default_backend(),
    )

    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, common_name)])
    alt_names = [x509.DNSName(common_name)]
    san = x509.SubjectAlternativeName(alt_names)

    # path_len=0 means this cert can only sign itself, not other certs.
    basic_contraints = x509.BasicConstraints(ca=True, path_length=0)
    now = datetime.now(timezone.utc)
    cert = (
        x509.CertificateBuilder()
        .subject_name(name)
        .issuer_name(name)
        .public_key(key.public_key())
        .serial_number(1000)
        .not_valid_before(now)
        .not_valid_after(now + timedelta(days=365))
        .add_extension(basic_contraints, False)
        .add_extension(san, False)
        .sign(key, hashes.SHA256(), default_backend())
    )
    exp_date = cert.not_valid_after_utc
    fullchain = cert.public_bytes(encoding=serialization.Encoding.PEM).decode("utf-8")
    privkey = key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode("utf-8")

    return fullchain, privkey, exp_date

import base64
from datetime import datetime, timedelta, timezone

from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.asymmetric import rsa


def sanitize_cert(cert: str):
    return base64.b64encode(bytearray(cert.strip() + "\n", "utf-8")).decode("utf-8")


def decode_cert(cert: str):
    return str(base64.b64decode(cert).decode("utf-8"))


def create_self_signed_cert(common_name: str = "*.ping-demo.com"):
    # Generate a private root CA and a leaf certificate signed by that root.
    root_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
        backend=default_backend(),
    )
    leaf_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
        backend=default_backend(),
    )

    root_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Test Root CA")])
    leaf_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, common_name)])
    alt_names = [x509.DNSName(common_name)]
    san = x509.SubjectAlternativeName(alt_names)

    now = datetime.now(timezone.utc)

    root_cert = (
        x509.CertificateBuilder()
        .subject_name(root_name)
        .issuer_name(root_name)
        .public_key(root_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now)
        .not_valid_after(now + timedelta(days=3650))
        .add_extension(x509.BasicConstraints(ca=True, path_length=0), critical=True)
        .sign(root_key, hashes.SHA256(), default_backend())
    )

    leaf_cert = (
        x509.CertificateBuilder()
        .subject_name(leaf_name)
        .issuer_name(root_name)
        .public_key(leaf_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now)
        .not_valid_after(now + timedelta(days=365))
        .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
        .add_extension(san, critical=False)
        .sign(root_key, hashes.SHA256(), default_backend())
    )
    exp_date = leaf_cert.not_valid_after_utc
    fullchain = leaf_cert.public_bytes(encoding=serialization.Encoding.PEM).decode(
        "utf-8"
    ) + root_cert.public_bytes(encoding=serialization.Encoding.PEM).decode("utf-8")
    privkey = leaf_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode("utf-8")

    return fullchain, privkey, exp_date

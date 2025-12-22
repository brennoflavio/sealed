from src.constants import (
    APP_NAME,
    CRASH_REPORT_URL,
)
from src.ut_components import setup

setup(APP_NAME, CRASH_REPORT_URL)

import base64
import json
import os
from base64 import urlsafe_b64decode, urlsafe_b64encode
from typing import Dict, Optional

from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

from src.ut_components.kv import KV


def generate_salt(length: int = 16) -> bytes:
    return os.urandom(length)


def generate_key_from_password(
    password: str,
) -> str:
    with KV() as kv:
        salt_str = kv.get("encryption.salt")
        if not salt_str:
            salt = os.urandom(16)
            kv.put("encryption.salt", urlsafe_b64encode(salt).decode("utf-8"))
        else:
            salt = urlsafe_b64decode(salt_str)
        iterations = 480000
        password_bytes = password.encode("utf-8")
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=iterations,
        )
        key = base64.urlsafe_b64encode(kdf.derive(password_bytes))
        return urlsafe_b64encode(key).decode("utf-8")


def encrypt(key: bytes, data: str) -> bytes:
    fernet = Fernet(key)
    data_bytes = data.encode("utf-8")
    encrypted_data = fernet.encrypt(data_bytes)
    return encrypted_data


def decrypt(key: bytes, encrypted_data: bytes) -> str:
    fernet = Fernet(key)
    decrypted_bytes = fernet.decrypt(encrypted_data)
    decrypted_string = decrypted_bytes.decode("utf-8")
    return decrypted_string


def save_encrypted(encryption_key: str, value_key: str, value: Dict) -> None:
    with KV() as kv:
        encrypted_value = encrypt(urlsafe_b64decode(encryption_key), json.dumps(value))
        kv.put(
            value_key,
            urlsafe_b64encode(encrypted_value).decode("utf-8"),
        )


def get_encrypted(encryption_key: str, value_key: str) -> Optional[Dict]:
    with KV() as kv:
        encrypted_value = kv.get(value_key)
        if encrypted_value:
            decrypted_value = decrypt(urlsafe_b64decode(encryption_key), urlsafe_b64decode(encrypted_value))
            return json.loads(decrypted_value)

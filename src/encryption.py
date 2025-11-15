from src.constants import (
    APP_NAME,
    CRASH_REPORT_URL,
)
from src.ut_components import setup

setup(APP_NAME, CRASH_REPORT_URL)

import base64
import hashlib
import json
import os
from base64 import urlsafe_b64decode, urlsafe_b64encode
from typing import Dict, Optional

from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

from src.ut_components.kv import KV
from src.ut_components.memoize import hash_function_args


def generate_salt(length: int = 16) -> bytes:
    return os.urandom(length)


def generate_key_from_password(
    password: str,
) -> bytes:
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
        return key


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


def memoize_enabled() -> bool:
    with KV() as kv:
        return bool(kv.get("encryption.enabled", True, True))


def set_memoize(enabled: bool) -> None:
    with KV() as kv:
        if enabled:
            kv.put("encryption.enabled", 1)
        else:
            kv.put("encryption.enabled", 0)


def hash_function_name_by_name(function_name: str) -> str:
    return hashlib.sha1(f"{function_name}".encode()).hexdigest()


def memoize_get(key: str, function_name: str, *args, **kwargs) -> Optional[Dict]:
    if not key or not memoize_enabled():
        return
    hashed_function_name = hash_function_name_by_name(function_name)
    hashed_encoded_args = hash_function_args(args, kwargs)
    with KV() as kv:
        memoization = kv.get(f"memoization.{hashed_function_name}.{hashed_encoded_args}")
        if memoization:
            decrypted_memoization = decrypt(urlsafe_b64decode(key), urlsafe_b64decode(memoization))
            return json.loads(decrypted_memoization)


def memoize_set(key: str, function_name: str, value: Dict, ttl_seconds: int, *args, **kwargs) -> None:
    if not key or not memoize_enabled():
        return
    hashed_function_name = hash_function_name_by_name(function_name)
    hashed_encoded_args = hash_function_args(args, kwargs)
    with KV() as kv:
        encrypted_memoization = encrypt(urlsafe_b64decode(key), json.dumps(value))
        kv.put(
            f"memoization.{hashed_function_name}.{hashed_encoded_args}",
            urlsafe_b64encode(encrypted_memoization).decode("utf-8"),
            ttl_seconds=ttl_seconds,
        )


def memoize_clear() -> None:
    with KV() as kv:
        kv.delete_partial("memoization")

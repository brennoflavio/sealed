"""
Copyright (C) 2025  Brenno Flávio de Almeida

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 3.

sealed is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
"""

from src.constants import APP_NAME, CRASH_REPORT_URL
from src.ut_components import setup
from src.utils import parse_bw_date

setup(APP_NAME, CRASH_REPORT_URL)
import secrets
import string
from dataclasses import asdict, dataclass
from datetime import timedelta
from functools import wraps
from typing import Any, Callable, Dict, List, Optional

import pyotherside
from cryptography.fernet import InvalidToken
from dacite import Config, from_dict

from src.bitwarden_client import (
    BitwardenItemType,
    BitwardenStatus,
    bitwarden_delete_folder,
    bitwarden_delete_item,
    bitwarden_edit_folder,
    bitwarden_edit_item,
    bitwarden_list_folders,
    bitwarden_list_items,
    bitwarden_login,
    bitwarden_logout,
    bitwarden_restore_item,
    bitwarden_save_folder,
    bitwarden_save_item,
    bitwarden_set_server,
    bitwarden_setup,
    bitwarden_status,
    bitwarden_sync,
    bitwarden_unlock,
)
from src.encryption import (
    generate_key_from_password,
    get_encrypted,
    save_encrypted,
)
from src.totp import generate_totp
from src.ut_components.crash import crash_reporter, get_crash_report, set_crash_report
from src.ut_components.enum import StrEnum
from src.ut_components.event import Event, get_event_dispatcher
from src.ut_components.kv import KV
from src.ut_components.utils import dataclass_to_dict

DACITE_CONFIG = Config(strict=True, cast=[BitwardenItemType])


def clear_loading_state() -> None:
    with KV() as kv:
        kv.delete("loading")


def loading_initial_state() -> bool:
    with KV() as kv:
        loading = kv.get("loading", False) or False
        return loading


def emit_loading(func: Callable) -> Callable:
    @wraps(func)
    def wrapper(*args, **kwargs) -> Any:
        with KV() as kv:
            kv.put("loading", True)
        pyotherside.send("loading", True)
        response = func(*args, **kwargs)
        with KV() as kv:
            kv.put("loading", False)
        pyotherside.send("loading", False)
        return response

    return wrapper


def start_event_loop():
    get_event_dispatcher().start()


def setup_bw():
    with KV() as kv:
        setup_done = kv.put("sealed.setup_done", False) or False
        if not setup_done:
            setup = bitwarden_setup()
            if not setup.success:
                raise Exception(f"failed to setup ({setup.success}) bitwarden with error: {setup.data}")
            kv.put("sealed.setup_done", True)


def set_session_key(encryption_key: str, session_key: str) -> None:
    save_encrypted(encryption_key, "bw.session_key", {"session_key": session_key})


def get_session_key(encryption_key: str) -> Optional[str]:
    result = get_encrypted(encryption_key, "bw.session_key")
    if result:
        return result.get("session_key")


def exist_session_key() -> bool:
    with KV() as kv:
        encrypted_key = kv.get("bw.session_key")
        if encrypted_key:
            return True
    return False


@dataclass
class StandardBitwardenResponse:
    success: bool
    message: str = ""


class LoginScreenFields(StrEnum):
    EMAIL = "email"
    PASSWORD = "password"
    TOTP = "totp"


@dataclass
class LoginScreen:
    show: bool
    fields: List[LoginScreenFields]


@crash_reporter
@dataclass_to_dict
def login_screen() -> LoginScreen:
    setup_bw()

    if exist_session_key():
        return LoginScreen(show=True, fields=[LoginScreenFields.PASSWORD])

    status = bitwarden_status()
    if status == BitwardenStatus.UNAUTHENTICATED:
        return LoginScreen(
            show=True, fields=[LoginScreenFields.EMAIL, LoginScreenFields.PASSWORD, LoginScreenFields.TOTP]
        )
    elif status == BitwardenStatus.LOCKED:
        return LoginScreen(show=True, fields=[LoginScreenFields.PASSWORD])
    elif status == BitwardenStatus.UNLOCKED:
        return LoginScreen(show=False, fields=[])
    else:
        raise Exception(f"Unknown Bitwarden status {status.value}")


@crash_reporter
@dataclass_to_dict
def login(email: str = "", password: str = "", code: str = "") -> StandardBitwardenResponse:
    if email:
        session_key_response = bitwarden_login(email, password, code)
        if not session_key_response.success:
            return StandardBitwardenResponse(
                success=False, message=f"Error during bitwarden login: {session_key_response.data}"
            )
        else:
            encryption_key = generate_key_from_password(password)
            set_session_key(encryption_key, session_key_response.data)
            return StandardBitwardenResponse(success=True, message=encryption_key)
    elif password:
        try:
            encryption_key = generate_key_from_password(password)
            session_key = get_session_key(encryption_key)
        except InvalidToken:
            return StandardBitwardenResponse(success=False, message="Invalid Password")
        if session_key:
            return StandardBitwardenResponse(success=True, message=encryption_key)
        else:
            session_key_response = bitwarden_unlock(password)
            if not session_key_response.success:
                return StandardBitwardenResponse(
                    success=False, message=f"Error during bitwarden unlock: {session_key_response.data}"
                )
            set_session_key(encryption_key, session_key_response.data)
            return StandardBitwardenResponse(success=True, message=encryption_key)
    return StandardBitwardenResponse(success=False, message="Unknown error happened")


@dataclass
class Item:
    id: str
    name: str
    username: str
    password: str
    favorite: bool
    item_type: BitwardenItemType
    notes: str
    created: str
    updated: str
    totp: str
    cardholder_name: str
    brand: str
    number: str
    expiry_month: str
    expiry_year: str
    code: str
    folder_id: str
    folder_name: str


@dataclass
class ListItemsResult:
    success: bool
    items: List[Item]


class BWKeys(StrEnum):
    LIST_ITEMS = "bw.list_items"
    CURRENT_TOTP_SECRET = "bw.current_totp_secret"
    LIST_TRASH_ITEMS = "bw.list_trash_items"
    LIST_FOLDERS = "bw.list_folders"
    LIST_FOLDER_ITEMS = "bw.list_folder_items"


class SyncItems(Event):
    @emit_loading
    def trigger(self, metadata: Dict) -> object:
        encryption_key = metadata.get("encryption_key")
        if not encryption_key:
            return ListItemsResult(success=False, items=[])

        session_key = get_session_key(encryption_key)
        if not session_key:
            return ListItemsResult(success=False, items=[])

        sync_result = bitwarden_sync(session_key)
        if not sync_result.success:
            return ListItemsResult(success=False, items=[])

        items = bitwarden_list_items(session_key)

        parsed_items = []
        for item in items:
            if item.item_type in (BitwardenItemType.LOGIN, BitwardenItemType.CARD):
                parsed_items.append(
                    Item(
                        id=item.id,
                        name=item.name or "",
                        username=item.username or "",
                        password=item.password or "",
                        favorite=item.favorite or False,
                        item_type=item.item_type or BitwardenItemType.LOGIN,
                        notes=item.notes or "",
                        created=parse_bw_date(item.creation_date),
                        updated=parse_bw_date(item.revision_date),
                        totp=item.totp or "",
                        cardholder_name=item.cardholder_name or "",
                        brand=item.brand or "",
                        number=item.number or "",
                        expiry_month=item.expiry_month.zfill(2) if item.expiry_month else "",
                        expiry_year=item.expiry_year.zfill(4) if item.expiry_year else "",
                        code=item.code or "",
                        folder_id=item.folder_id or "",
                        folder_name=item.folder_name or "",
                    )
                )

        response = ListItemsResult(success=True, items=sorted(parsed_items, key=lambda x: (not x.favorite, x.name)))
        save_encrypted(encryption_key, BWKeys.LIST_ITEMS, asdict(response))
        return response


get_event_dispatcher().register_event(SyncItems(id="sync-items"))

# TODO: implement totp


@dataclass
class Folder:
    id: str
    name: str


@dataclass
class ListFolderResult:
    success: bool
    folders: List[Folder]


class SyncFoldersEvent(Event):
    @emit_loading
    def trigger(self, metadata: Dict) -> object:
        encryption_key = metadata.get("encryption_key")
        if not encryption_key:
            return ListFolderResult(success=False, folders=[])

        session_key = get_session_key(encryption_key)
        if not session_key:
            return ListFolderResult(success=False, folders=[])

        sync_result = bitwarden_sync(session_key)
        if not sync_result.success:
            return ListFolderResult(success=False, folders=[])

        items = bitwarden_list_folders(session_key)
        parsed_folders = []
        for folder in items:
            parsed_folders.append(
                Folder(
                    id=folder.id,
                    name=folder.name or "",
                )
            )

        response = ListFolderResult(success=True, folders=sorted(parsed_folders, key=lambda x: x.name))
        save_encrypted(encryption_key, BWKeys.LIST_FOLDERS, asdict(response))
        return response


get_event_dispatcher().register_event(SyncFoldersEvent(id="sync-folders"))


@crash_reporter
@dataclass_to_dict
def list_items(encryption_key: str) -> ListItemsResult:
    get_event_dispatcher().schedule(event_id="sync-items", metadata={"encryption_key": encryption_key})
    get_event_dispatcher().schedule(event_id="sync-folders", metadata={"encryption_key": encryption_key})

    items = get_encrypted(encryption_key, BWKeys.LIST_ITEMS)
    if not items:
        return ListItemsResult(success=True, items=[])

    parsed_items = from_dict(ListItemsResult, items, DACITE_CONFIG)
    return parsed_items


@dataclass
class Totp:
    code: str


@crash_reporter
@dataclass_to_dict
def get_totp(secret: str) -> Totp:
    if not secret:
        return Totp(code="")
    try:
        return Totp(code=generate_totp(secret))
    except Exception:
        return Totp(code="")


@crash_reporter
@dataclass_to_dict
def add_login(
    encryption_key: str,
    name: str,
    username: str = "",
    password: str = "",
    notes: str = "",
    totp: str = "",
    favorite: bool = False,
    folder_id: str = "",
):
    session_key = get_session_key(encryption_key)

    if not session_key:
        raise Exception("No session code found")

    result = bitwarden_save_item(
        type=BitwardenItemType.LOGIN,
        session_code=session_key,
        name=name,
        username=username,
        password=password,
        notes=notes,
        totp=totp,
        favorite=favorite,
        folder_id=folder_id,
    )
    get_event_dispatcher().schedule(event_id="sync-items", metadata={"encryption_key": encryption_key})
    if result.success:
        return StandardBitwardenResponse(success=True)
    else:
        return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
@dataclass_to_dict
def add_card(
    encryption_key: str,
    name: str,
    cardholder_name: str = "",
    brand: str = "",
    number: str = "",
    exp_month: str = "",
    exp_year: str = "",
    code: str = "",
    favorite: bool = False,
    folder_id: str = "",
):
    session_key = get_session_key(encryption_key)

    if not session_key:
        raise Exception("No session code found")

    result = bitwarden_save_item(
        type=BitwardenItemType.CARD,
        session_code=session_key,
        name=name,
        cardholder_name=cardholder_name,
        brand=brand,
        number=number,
        exp_month=exp_month,
        exp_year=exp_year,
        code=code,
        favorite=favorite,
        folder_id=folder_id,
    )
    get_event_dispatcher().schedule(event_id="sync-items", metadata={"encryption_key": encryption_key})
    if result.success:
        return StandardBitwardenResponse(success=True)
    else:
        return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
@dataclass_to_dict
def edit_login(
    encryption_key: str,
    id: str,
    name: str,
    username: str = "",
    password: str = "",
    notes: str = "",
    totp: str = "",
    favorite: bool = False,
    folder_id: str = "",
):
    session_key = get_session_key(encryption_key)

    if not session_key:
        raise Exception("No session code found")

    result = bitwarden_edit_item(
        session_code=session_key,
        id=id,
        name=name,
        username=username,
        password=password,
        notes=notes,
        totp=totp,
        favorite=favorite,
        folder_id=folder_id,
    )
    get_event_dispatcher().schedule(event_id="sync-items", metadata={"encryption_key": encryption_key})
    if result.success:
        return StandardBitwardenResponse(success=True)
    else:
        return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
@dataclass_to_dict
def edit_card(
    encryption_key: str,
    id: str,
    name: str,
    cardholder_name: str = "",
    brand: str = "",
    number: str = "",
    exp_month: str = "",
    exp_year: str = "",
    code: str = "",
    favorite: bool = False,
    folder_id: str = "",
):
    session_key = get_session_key(encryption_key)

    if not session_key:
        raise Exception("No session code found")

    result = bitwarden_edit_item(
        session_code=session_key,
        id=id,
        name=name,
        cardholder_name=cardholder_name,
        brand=brand,
        number=number,
        exp_month=exp_month,
        exp_year=exp_year,
        code=code,
        favorite=favorite,
        folder_id=folder_id,
    )
    get_event_dispatcher().schedule(event_id="sync-items", metadata={"encryption_key": encryption_key})
    if result.success:
        return StandardBitwardenResponse(success=True)
    else:
        return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
@dataclass_to_dict
def refresh(encryption_key: str) -> StandardBitwardenResponse:
    get_event_dispatcher().schedule(event_id="sync-items", metadata={"encryption_key": encryption_key})
    return StandardBitwardenResponse(success=True)


@crash_reporter
@dataclass_to_dict
def set_server(url: str) -> StandardBitwardenResponse:
    setup_bw()

    response = bitwarden_set_server(url)
    if not response.success:
        return StandardBitwardenResponse(success=False, message=response.data)

    with KV() as kv:
        kv.delete_partial("bw")
        kv.put("config.server_url", url)
    return StandardBitwardenResponse(success=True)


@dataclass
class Configuration:
    server_url: str
    crash_logs: bool


@crash_reporter
@dataclass_to_dict
def get_configuration() -> Configuration:
    with KV() as kv:
        server_url = kv.get("config.server_url", "bitwarden.com", True) or "bitwarden.com"
        crash_logs = get_crash_report()
    return Configuration(server_url=server_url, crash_logs=crash_logs)


def set_crash_logs(enabled: bool):
    return set_crash_report(enabled)


@crash_reporter
@dataclass_to_dict
def logout() -> StandardBitwardenResponse:
    with KV() as kv:
        kv.delete_partial("sealed")
        kv.delete_partial("bw")

        response = bitwarden_logout()
        if not response.success:
            if "not logged in" in response.data.lower():
                return StandardBitwardenResponse(success=True)
            return StandardBitwardenResponse(success=False, message=response.data)
        return StandardBitwardenResponse(success=True)


def generate_password() -> str:
    characters = string.ascii_letters + string.digits
    password = "".join(secrets.choice(characters) for _ in range(16))
    return password


class SyncTrashItems(Event):
    @emit_loading
    def trigger(self, metadata: Dict) -> object:
        encryption_key = metadata.get("encryption_key")
        if not encryption_key:
            return ListItemsResult(success=False, items=[])

        session_key = get_session_key(encryption_key)
        if not session_key:
            return ListItemsResult(success=False, items=[])

        sync_result = bitwarden_sync(session_key)
        if not sync_result.success:
            return ListItemsResult(success=False, items=[])

        items = bitwarden_list_items(session_key, trash=True)

        parsed_items = []
        for item in items:
            if item.item_type in (BitwardenItemType.LOGIN, BitwardenItemType.CARD):
                parsed_items.append(
                    Item(
                        id=item.id,
                        name=item.name or "",
                        username=item.username or "",
                        password=item.password or "",
                        favorite=item.favorite or False,
                        item_type=item.item_type or BitwardenItemType.LOGIN,
                        notes=item.notes or "",
                        created=parse_bw_date(item.creation_date),
                        updated=parse_bw_date(item.revision_date),
                        totp=item.totp or "",
                        cardholder_name=item.cardholder_name or "",
                        brand=item.brand or "",
                        number=item.number or "",
                        expiry_month=item.expiry_month.zfill(2) if item.expiry_month else "",
                        expiry_year=item.expiry_year.zfill(4) if item.expiry_year else "",
                        code=item.code or "",
                        folder_id=item.folder_id or "",
                        folder_name=item.folder_name or "",
                    )
                )

        response = ListItemsResult(success=True, items=sorted(parsed_items, key=lambda x: (not x.favorite, x.name)))
        save_encrypted(encryption_key, BWKeys.LIST_TRASH_ITEMS, asdict(response))
        return response


get_event_dispatcher().register_event(SyncTrashItems(id="sync-trash-items"))

# TODO: load are broken in main and trash, shows no items while its loading


@crash_reporter
@dataclass_to_dict
def list_trash(encryption_key: str) -> ListItemsResult:
    get_event_dispatcher().schedule(event_id="sync-trash-items", metadata={"encryption_key": encryption_key})

    items = get_encrypted(encryption_key, BWKeys.LIST_TRASH_ITEMS)
    if not items:
        return ListItemsResult(success=True, items=[])

    parsed_items = from_dict(ListItemsResult, items, DACITE_CONFIG)
    return parsed_items


@crash_reporter
@dataclass_to_dict
def refresh_trash(encryption_key: str) -> StandardBitwardenResponse:
    get_event_dispatcher().schedule(event_id="sync-trash-items", metadata={"encryption_key": encryption_key})
    return StandardBitwardenResponse(success=True)


@crash_reporter
def trash_item(encryption_key: str, item_id: str) -> StandardBitwardenResponse:
    session_key = get_session_key(encryption_key)

    if not session_key:
        return StandardBitwardenResponse(success=False, message="Not logged in")

    result = bitwarden_delete_item(session_key, item_id)
    get_event_dispatcher().schedule(event_id="sync-trash-items", metadata={"encryption_key": encryption_key})
    get_event_dispatcher().schedule(event_id="sync-items", metadata={"encryption_key": encryption_key})
    if result.success:
        return StandardBitwardenResponse(success=True)
    else:
        return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
def delete_item(encryption_key: str, item_id: str) -> StandardBitwardenResponse:
    session_key = get_session_key(encryption_key)

    if not session_key:
        return StandardBitwardenResponse(success=False, message="Not logged in")

    result = bitwarden_delete_item(session_key, item_id, permanent=True)
    get_event_dispatcher().schedule(event_id="sync-trash-items", metadata={"encryption_key": encryption_key})
    if result.success:
        return StandardBitwardenResponse(success=True)
    else:
        return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
def restore_item(encryption_key: str, item_id: str) -> StandardBitwardenResponse:
    session_key = get_session_key(encryption_key)

    if not session_key:
        return StandardBitwardenResponse(success=False, message="Not logged in")

    result = bitwarden_restore_item(session_key, item_id)
    get_event_dispatcher().schedule(event_id="sync-trash-items", metadata={"encryption_key": encryption_key})
    get_event_dispatcher().schedule(event_id="sync-items", metadata={"encryption_key": encryption_key})
    if result.success:
        return StandardBitwardenResponse(success=True)
    else:
        return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
@dataclass_to_dict
def list_folders(encryption_key: str) -> ListFolderResult:
    get_event_dispatcher().schedule(event_id="sync-folders", metadata={"encryption_key": encryption_key})

    items = get_encrypted(encryption_key, BWKeys.LIST_FOLDERS)
    if not items:
        return ListFolderResult(success=True, folders=[])

    parsed_items = from_dict(ListFolderResult, items, DACITE_CONFIG)
    return parsed_items


@crash_reporter
@dataclass_to_dict
def refresh_folders(encryption_key: str) -> StandardBitwardenResponse:
    get_event_dispatcher().schedule(event_id="sync-folders", metadata={"encryption_key": encryption_key})
    return StandardBitwardenResponse(success=True)


@crash_reporter
@dataclass_to_dict
def add_folder(encryption_key: str, name: str) -> StandardBitwardenResponse:
    session_key = get_session_key(encryption_key)

    if not session_key:
        raise Exception("No session code found")

    result = bitwarden_save_folder(
        session_code=session_key,
        name=name,
    )
    get_event_dispatcher().schedule(event_id="sync-folders", metadata={"encryption_key": encryption_key})
    if result.success:
        return StandardBitwardenResponse(success=True)
    else:
        return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
@dataclass_to_dict
def delete_folder(encryption_key: str, folder_id: str) -> StandardBitwardenResponse:
    session_key = get_session_key(encryption_key)

    if not session_key:
        return StandardBitwardenResponse(success=False, message="Not logged in")

    result = bitwarden_delete_folder(session_key, folder_id)
    get_event_dispatcher().schedule(event_id="sync-folders", metadata={"encryption_key": encryption_key})
    if result.success:
        return StandardBitwardenResponse(success=True)
    else:
        return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
@dataclass_to_dict
def edit_folder(encryption_key: str, folder_id: str, name: str) -> StandardBitwardenResponse:
    session_key = get_session_key(encryption_key)

    if not session_key:
        return StandardBitwardenResponse(success=False, message="Not logged in")

    result = bitwarden_edit_folder(session_key, folder_id, name)
    get_event_dispatcher().schedule(event_id="sync-folders", metadata={"encryption_key": encryption_key})
    if result.success:
        return StandardBitwardenResponse(success=True)
    else:
        return StandardBitwardenResponse(success=False, message=result.data)


class SyncFolderItems(Event):
    @emit_loading
    def trigger(self, metadata: Dict) -> object:
        encryption_key = metadata.get("encryption_key")
        folder_id = metadata.get("folder_id")

        if not encryption_key or not folder_id:
            return ListItemsResult(success=False, items=[])

        session_key = get_session_key(encryption_key)
        if not session_key:
            return ListItemsResult(success=False, items=[])

        sync_result = bitwarden_sync(session_key)
        if not sync_result.success:
            return ListItemsResult(success=False, items=[])

        items = bitwarden_list_items(session_key, folder_id=folder_id)

        parsed_items = []
        for item in items:
            if item.item_type in (BitwardenItemType.LOGIN, BitwardenItemType.CARD):
                parsed_items.append(
                    Item(
                        id=item.id,
                        name=item.name or "",
                        username=item.username or "",
                        password=item.password or "",
                        favorite=item.favorite or False,
                        item_type=item.item_type or BitwardenItemType.LOGIN,
                        notes=item.notes or "",
                        created=parse_bw_date(item.creation_date),
                        updated=parse_bw_date(item.revision_date),
                        totp=item.totp or "",
                        cardholder_name=item.cardholder_name or "",
                        brand=item.brand or "",
                        number=item.number or "",
                        expiry_month=item.expiry_month.zfill(2) if item.expiry_month else "",
                        expiry_year=item.expiry_year.zfill(4) if item.expiry_year else "",
                        code=item.code or "",
                        folder_id=item.folder_id or "",
                        folder_name=item.folder_name or "",
                    )
                )

        response = ListItemsResult(success=True, items=sorted(parsed_items, key=lambda x: (not x.favorite, x.name)))
        save_encrypted(encryption_key, f"{BWKeys.LIST_FOLDER_ITEMS}.{folder_id}", asdict(response))
        return response


get_event_dispatcher().register_event(SyncFolderItems(id="sync-folder-items"))


@dataclass
class SessionValidationResult:
    valid: bool
    logged_out: bool


class ValidateSessionKeyEvent(Event):
    def __init__(self):
        super().__init__(id="validate-session-key", execution_interval=timedelta(seconds=30))

    def trigger(self, metadata: Dict) -> object:
        # Check if a session key exists in storage
        if not exist_session_key():
            # No session key stored, nothing to validate
            return SessionValidationResult(valid=True, logged_out=False)

        # Check the Bitwarden CLI status
        try:
            status = bitwarden_status()
        except Exception:
            # If we can't check status, assume session is valid
            return SessionValidationResult(valid=True, logged_out=False)

        # If status is UNAUTHENTICATED or LOCKED, the session is invalid
        if status in (BitwardenStatus.UNAUTHENTICATED, BitwardenStatus.LOCKED):
            # Clear the session key and all cached Bitwarden data
            with KV() as kv:
                kv.delete_partial("bw")

            # Notify the UI that the session is invalid
            return SessionValidationResult(valid=False, logged_out=True)

        # Session is valid
        return SessionValidationResult(valid=True, logged_out=False)


get_event_dispatcher().register_event(ValidateSessionKeyEvent())


@crash_reporter
@dataclass_to_dict
def list_folder(encryption_key: str, folder_id: str) -> ListItemsResult:
    get_event_dispatcher().schedule(
        event_id="sync-folder-items", metadata={"encryption_key": encryption_key, "folder_id": folder_id}
    )

    items = get_encrypted(encryption_key, f"{BWKeys.LIST_FOLDER_ITEMS}.{folder_id}")
    if not items:
        return ListItemsResult(success=True, items=[])

    parsed_items = from_dict(ListItemsResult, items, DACITE_CONFIG)
    return parsed_items


@crash_reporter
@dataclass_to_dict
def refresh_folder(encryption_key: str, folder_id: str) -> StandardBitwardenResponse:
    get_event_dispatcher().schedule(
        event_id="sync-folder-items", metadata={"encryption_key": encryption_key, "folder_id": folder_id}
    )
    return StandardBitwardenResponse(success=True)

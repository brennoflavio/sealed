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

from src.constants import (
    APP_NAME,
    CRASH_REPORT_URL,
)
from src.ut_components import setup
from src.utils import parse_bw_date

setup(APP_NAME, CRASH_REPORT_URL)
import secrets
import string
from dataclasses import dataclass
from enum import Enum
from typing import List

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
from src.totp import generate_totp
from src.ut_components.crash import crash_reporter, get_crash_report, set_crash_report
from src.ut_components.kv import KV
from src.ut_components.utils import dataclass_to_dict


def setup_bw():
    with KV() as kv:
        setup_done = kv.put("sealed.setup_done", False) or False
        if not setup_done:
            setup = bitwarden_setup()
            if not setup.success:
                raise Exception(f"failed to setup ({setup.success}) bitwarden with error: {setup.data}")
            kv.put("sealed.setup_done", True)


@dataclass
class StandardBitwardenResponse:
    success: bool
    message: str = ""


class LoginScreenFields(Enum):
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
        session_code = bitwarden_login(email, password, code)
        if not session_code.success:
            return StandardBitwardenResponse(success=False, message=session_code.data)
    else:
        session_code = bitwarden_unlock(password)
        if not session_code.success:
            return StandardBitwardenResponse(success=False, message=session_code.data)
    with KV() as kv:
        kv.put("bw.session_code", session_code.data)
    return StandardBitwardenResponse(success=True)


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


@crash_reporter
@dataclass_to_dict
def list_items() -> ListItemsResult:
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            return ListItemsResult(success=False, items=[])

        synced = kv.get("sealed.synced") or False
        if not synced:
            sync_result = bitwarden_sync(session_code)
            if not sync_result.success:
                return ListItemsResult(success=False, items=[])
            kv.put("sealed.synced", True, ttl_seconds=86400)

        items = bitwarden_list_items(session_code)
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

    return ListItemsResult(success=True, items=sorted(parsed_items, key=lambda x: (not x.favorite, x.name)))


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
    name: str,
    username: str = "",
    password: str = "",
    notes: str = "",
    totp: str = "",
    favorite: bool = False,
    folder_id: str = "",
):
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            raise Exception("No session code found")

        result = bitwarden_save_item(
            type=BitwardenItemType.LOGIN,
            session_code=session_code,
            name=name,
            username=username,
            password=password,
            notes=notes,
            totp=totp,
            favorite=favorite,
            folder_id=folder_id,
        )
        if result.success:
            return StandardBitwardenResponse(success=True)
        else:
            return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
@dataclass_to_dict
def add_card(
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
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            raise Exception("No session code found")

        result = bitwarden_save_item(
            type=BitwardenItemType.CARD,
            session_code=session_code,
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
        if result.success:
            return StandardBitwardenResponse(success=True)
        else:
            return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
@dataclass_to_dict
def edit_login(
    id: str,
    name: str,
    username: str = "",
    password: str = "",
    notes: str = "",
    totp: str = "",
    favorite: bool = False,
    folder_id: str = "",
):
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            raise Exception("No session code found")

        result = bitwarden_edit_item(
            session_code=session_code,
            id=id,
            name=name,
            username=username,
            password=password,
            notes=notes,
            totp=totp,
            favorite=favorite,
            folder_id=folder_id,
        )
        if result.success:
            return StandardBitwardenResponse(success=True)
        else:
            return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
@dataclass_to_dict
def edit_card(
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
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            raise Exception("No session code found")

        result = bitwarden_edit_item(
            session_code=session_code,
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
        if result.success:
            return StandardBitwardenResponse(success=True)
        else:
            return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
@dataclass_to_dict
def refresh() -> StandardBitwardenResponse:
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            return StandardBitwardenResponse(success=False, message="Not logged in")

        sync_result = bitwarden_sync(session_code)
        if not sync_result.success:
            return StandardBitwardenResponse(success=False, message="Failed to sync")
        kv.put("sealed.synced", True, ttl_seconds=86400)
        return StandardBitwardenResponse(success=True)


@crash_reporter
def cleanup():
    with KV() as kv:
        kv.delete_partial("bw")


@crash_reporter
@dataclass_to_dict
def set_server(url: str) -> StandardBitwardenResponse:
    setup_bw()

    response = bitwarden_set_server(url)
    if not response.success:
        return StandardBitwardenResponse(success=False, message=response.data)

    with KV() as kv:
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


@crash_reporter
@dataclass_to_dict
def list_trash() -> ListItemsResult:
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            return ListItemsResult(success=False, items=[])

        synced = kv.get("sealed.synced") or False
        if not synced:
            sync_result = bitwarden_sync(session_code)
            if not sync_result.success:
                return ListItemsResult(success=False, items=[])
            kv.put("sealed.synced", True, ttl_seconds=86400)

        items = bitwarden_list_items(session_code, trash=True)
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

    return ListItemsResult(success=True, items=sorted(parsed_items, key=lambda x: (not x.favorite, x.name)))


@crash_reporter
def trash_item(item_id: str) -> StandardBitwardenResponse:
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            return StandardBitwardenResponse(success=False, message="Not logged in")

        result = bitwarden_delete_item(session_code, item_id)
        if result.success:
            return StandardBitwardenResponse(success=True)
        else:
            return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
def delete_item(item_id: str) -> StandardBitwardenResponse:
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            return StandardBitwardenResponse(success=False, message="Not logged in")

        result = bitwarden_delete_item(session_code, item_id, permanent=True)
        if result.success:
            return StandardBitwardenResponse(success=True)
        else:
            return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
def restore_item(item_id: str) -> StandardBitwardenResponse:
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            return StandardBitwardenResponse(success=False, message="Not logged in")

        result = bitwarden_restore_item(session_code, item_id)
        if result.success:
            return StandardBitwardenResponse(success=True)
        else:
            return StandardBitwardenResponse(success=False, message=result.data)


@dataclass
class Folder:
    id: str
    name: str


@dataclass
class ListFolderResult:
    success: bool
    folders: List[Folder]


@crash_reporter
@dataclass_to_dict
def list_folders() -> ListFolderResult:
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            return ListFolderResult(success=False, folders=[])

        synced = kv.get("sealed.synced") or False
        if not synced:
            sync_result = bitwarden_sync(session_code)
            if not sync_result.success:
                return ListFolderResult(success=False, folders=[])
            kv.put("sealed.synced", True, ttl_seconds=86400)

        items = bitwarden_list_folders(session_code)
        parsed_folders = []
        for folder in items:
            parsed_folders.append(
                Folder(
                    id=folder.id,
                    name=folder.name or "",
                )
            )

    return ListFolderResult(success=True, folders=sorted(parsed_folders, key=lambda x: x.name))


@crash_reporter
@dataclass_to_dict
def add_folder(name: str) -> StandardBitwardenResponse:
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            raise Exception("No session code found")

        result = bitwarden_save_folder(
            session_code=session_code,
            name=name,
        )
        if result.success:
            return StandardBitwardenResponse(success=True)
        else:
            return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
@dataclass_to_dict
def list_folder(folder_id: str) -> ListItemsResult:
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            return ListItemsResult(success=False, items=[])

        synced = kv.get("sealed.synced") or False
        if not synced:
            sync_result = bitwarden_sync(session_code)
            if not sync_result.success:
                return ListItemsResult(success=False, items=[])
            kv.put("sealed.synced", True, ttl_seconds=86400)

        items = bitwarden_list_items(session_code, folder_id=folder_id)
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

    return ListItemsResult(success=True, items=sorted(parsed_items, key=lambda x: (not x.favorite, x.name)))


@crash_reporter
@dataclass_to_dict
def delete_folder(folder_id: str) -> StandardBitwardenResponse:
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            return StandardBitwardenResponse(success=False, message="Not logged in")

        result = bitwarden_delete_folder(session_code, folder_id)
        if result.success:
            return StandardBitwardenResponse(success=True)
        else:
            return StandardBitwardenResponse(success=False, message=result.data)


@crash_reporter
@dataclass_to_dict
def edit_folder(folder_id: str, name: str) -> StandardBitwardenResponse:
    with KV() as kv:
        session_code = kv.get("bw.session_code")

        if not session_code:
            return StandardBitwardenResponse(success=False, message="Not logged in")

        result = bitwarden_edit_folder(session_code, folder_id, name)
        if result.success:
            return StandardBitwardenResponse(success=True)
        else:
            return StandardBitwardenResponse(success=False, message=result.data)

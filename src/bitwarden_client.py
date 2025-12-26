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

import json
import traceback
from base64 import b64encode
from dataclasses import dataclass
from typing import Dict, List, Optional

from src.ut_components.enum import StrEnum
from src.utils import run_bw


@dataclass
class BitwardenClientResponse:
    success: bool
    data: str


class BitwardenStatus(StrEnum):
    UNAUTHENTICATED = "unauthenticated"
    LOCKED = "locked"
    UNLOCKED = "unlocked"


def bitwarden_setup() -> BitwardenClientResponse:
    try:
        run_bw(["help"])
        return BitwardenClientResponse(success=True, data="")
    except Exception:
        return BitwardenClientResponse(success=False, data=traceback.format_exc())


def bitwarden_status() -> BitwardenStatus:
    result = run_bw(["status"])
    if "unable to fetch serverconfig" in result.data.lower():
        return BitwardenStatus.UNAUTHENTICATED

    json_result = result.json()
    status = json_result.get("status", "unauthenticated")
    return BitwardenStatus[status.upper()]


def bitwarden_login(email: str, password: str, code: Optional[str] = None) -> BitwardenClientResponse:
    cmd = ["login"]
    if code:
        cmd.extend(["--method", "0", "--code", code])

    cmd.extend([email, password])

    try:
        result = run_bw(cmd)
    except Exception as e:
        if "no provider selected" in str(e).lower():
            return BitwardenClientResponse(success=False, data="need to input two factor code")
        else:
            return BitwardenClientResponse(success=False, data=str(e))
    return BitwardenClientResponse(success=True, data=result.data)


def bitwarden_unlock(password: str) -> BitwardenClientResponse:
    try:
        result = run_bw(["unlock", password])
    except Exception as e:
        return BitwardenClientResponse(success=False, data=str(e))
    return BitwardenClientResponse(success=True, data=result.data)


@dataclass
class BitwardenFolder:
    id: str
    name: str


def bitwarden_list_folders(session_code: str) -> List[BitwardenFolder]:
    args = ["list", "folders"]
    result = run_bw(args, env={"BW_SESSION": session_code})
    folder_list = result.json()

    bitwarden_folders = []
    for folder in folder_list:
        folder_id = folder.get("id")
        if folder_id:
            folder_name = folder.get("name")

            bitwarden_folders.append(BitwardenFolder(id=folder_id, name=folder_name))

    return bitwarden_folders


def bitwarden_save_folder(
    session_code: str,
    name: str,
):
    item = {"name": name}

    try:
        run_bw(["create", "folder", b64encode(json.dumps(item).encode()).decode()], env={"BW_SESSION": session_code})
    except Exception as e:
        return BitwardenClientResponse(success=False, data=str(e))
    return BitwardenClientResponse(success=True, data="")


def bitwarden_edit_folder(session_code: str, id: str, name: str):
    item = {"name": name}

    try:
        run_bw(["edit", "folder", id, b64encode(json.dumps(item).encode()).decode()], env={"BW_SESSION": session_code})
    except Exception as e:
        return BitwardenClientResponse(success=False, data=str(e))
    return BitwardenClientResponse(success=True, data="")


def bitwarden_delete_folder(
    session_code: str,
    id: str,
):
    try:
        run_bw(["delete", "folder", id], env={"BW_SESSION": session_code})
    except Exception as e:
        return BitwardenClientResponse(success=False, data=str(e))
    return BitwardenClientResponse(success=True, data="")


class BitwardenItemType(StrEnum):
    LOGIN = "login"
    SECURE_NOTE = "secure_note"
    CARD = "card"
    IDENTITY = "identity"
    SSH_KEY = "ssh_key"


def item_type_map(item_type: int) -> BitwardenItemType:
    if item_type == 1:
        return BitwardenItemType.LOGIN
    elif item_type == 2:
        return BitwardenItemType.SECURE_NOTE
    elif item_type == 3:
        return BitwardenItemType.CARD
    elif item_type == 4:
        return BitwardenItemType.IDENTITY
    elif item_type == 5:
        return BitwardenItemType.SSH_KEY
    else:
        raise ValueError(f"Unknown item type: {item_type}")


@dataclass
class BitwardenItem:
    id: str
    name: str
    username: str
    password: str
    totp: str
    notes: str
    creation_date: str
    revision_date: str
    favorite: bool
    item_type: BitwardenItemType
    cardholder_name: str
    brand: str
    number: str
    expiry_month: str
    expiry_year: str
    code: str
    raw: Dict
    folder_id: str
    folder_name: str


def bitwarden_list_items(
    session_code: str, trash: bool = False, folder_id: Optional[str] = None
) -> List[BitwardenItem]:
    args = ["list", "items"]
    if trash:
        args.append("--trash")
    if folder_id:
        args.extend(["--folderid", folder_id])

    result = run_bw(args, env={"BW_SESSION": session_code})
    items_list = result.json()

    folders = bitwarden_list_folders(session_code)

    bitwarden_items = []
    for item in items_list:
        item_id = item.get("id")
        item_name = item.get("name")
        item_username = item.get("login", {}).get("username")
        item_password = item.get("login", {}).get("password")
        item_totp = item.get("login", {}).get("totp")
        item_notes = item.get("notes")
        item_creation_date = item.get("creationDate")
        item_revision_date = item.get("revisionDate")
        item_favorite = item.get("favorite", False)
        item_cardholder_name = item.get("card", {}).get("cardholderName")
        item_brand = item.get("card", {}).get("brand")
        item_number = item.get("card", {}).get("number")
        item_expiry_month = item.get("card", {}).get("expMonth")
        item_expiry_year = item.get("card", {}).get("expYear")
        item_code = item.get("card", {}).get("code")
        found_folder_id = item.get("folderId", "")
        folder = [x for x in folders if x.id == found_folder_id]
        if folder:
            folder_name = folder[0].name
        else:
            folder_name = ""

        bitwarden_items.append(
            BitwardenItem(
                id=item_id,
                name=item_name,
                username=item_username,
                password=item_password,
                totp=item_totp,
                notes=item_notes,
                creation_date=item_creation_date,
                revision_date=item_revision_date,
                favorite=item_favorite,
                item_type=item_type_map(item.get("type", 1)),
                cardholder_name=item_cardholder_name,
                brand=item_brand,
                number=item_number,
                expiry_month=item_expiry_month,
                expiry_year=item_expiry_year,
                code=item_code,
                raw=item,
                folder_id=found_folder_id,
                folder_name=folder_name,
            )
        )

    return bitwarden_items


def bitwarden_get_item(session_code: str, item_id: str) -> BitwardenItem:
    result = run_bw(["get", "item", item_id], env={"BW_SESSION": session_code})
    item = result.json()

    item_id = item.get("id")
    item_name = item.get("name")
    item_username = item.get("login", {}).get("username")
    item_password = item.get("login", {}).get("password")
    item_totp = item.get("login", {}).get("totp")
    item_notes = item.get("notes")
    item_creation_date = item.get("creationDate")
    item_revision_date = item.get("revisionDate")
    item_favorite = item.get("favorite", False)
    item_cardholder_name = item.get("card", {}).get("cardholderName")
    item_brand = item.get("card", {}).get("brand")
    item_number = item.get("card", {}).get("number")
    item_expiry_month = item.get("card", {}).get("expMonth")
    item_expiry_year = item.get("card", {}).get("expYear")
    item_code = item.get("card", {}).get("code")
    item_folder_id = item.get("folderId", "")

    if item_folder_id:
        folders = bitwarden_list_folders(session_code)
        folder = [x for x in folders if x.id == item_folder_id]
        if folder:
            folder_name = folder[0].name
        else:
            folder_name = ""
    else:
        folder_name = ""

    return BitwardenItem(
        id=item_id,
        name=item_name,
        username=item_username,
        password=item_password,
        totp=item_totp,
        notes=item_notes,
        creation_date=item_creation_date,
        revision_date=item_revision_date,
        favorite=item_favorite,
        item_type=item_type_map(item.get("type", 1)),
        cardholder_name=item_cardholder_name,
        brand=item_brand,
        number=item_number,
        expiry_month=item_expiry_month,
        expiry_year=item_expiry_year,
        code=item_code,
        raw=item,
        folder_id=item_folder_id,
        folder_name=folder_name,
    )


def bitwarden_save_item(
    type: BitwardenItemType,
    session_code: str,
    name: str,
    username: Optional[str] = "",
    password: Optional[str] = "",
    notes: Optional[str] = "",
    totp: Optional[str] = "",
    cardholder_name: Optional[str] = "",
    brand: Optional[str] = "",
    number: Optional[str] = "",
    exp_month: Optional[str] = None,
    exp_year: Optional[str] = None,
    code: Optional[str] = "",
    favorite: Optional[bool] = False,
    folder_id: Optional[str] = None,
):
    if not username:
        username = None
    if not password:
        password = None
    if not notes:
        notes = None
    if not totp:
        totp = None
    if not folder_id:
        folder_id = None

    if type == BitwardenItemType.LOGIN:
        login = {"uris": [], "username": username, "password": password, "totp": totp, "fido2Credentials": []}
        card = None
        type_ = 1
    elif type == BitwardenItemType.CARD:
        card = {
            "cardholderName": cardholder_name,
            "brand": brand,
            "number": number,
            "expMonth": exp_month,
            "expYear": exp_year,
            "code": code,
        }
        login = None
        type_ = 3
    else:
        raise ValueError("Only LOGIN and CARD types are supported for saving items.")

    item = {
        "passwordHistory": [],
        "revisionDate": None,
        "creationDate": None,
        "deletedDate": None,
        "organizationId": None,
        "collectionIds": None,
        "folderId": folder_id,
        "type": type_,
        "name": name,
        "notes": notes,
        "favorite": favorite,
        "fields": [],
        "login": login,
        "secureNote": None,
        "card": card,
        "identity": None,
        "sshKey": None,
        "reprompt": 0,
    }

    try:
        run_bw(["create", "item", b64encode(json.dumps(item).encode()).decode()], env={"BW_SESSION": session_code})
    except Exception as e:
        return BitwardenClientResponse(success=False, data=str(e))
    return BitwardenClientResponse(success=True, data="")


def bitwarden_edit_item(
    session_code: str,
    id: str,
    name: Optional[str] = "",
    username: Optional[str] = "",
    password: Optional[str] = "",
    notes: Optional[str] = "",
    totp: Optional[str] = "",
    cardholder_name: Optional[str] = "",
    brand: Optional[str] = "",
    number: Optional[str] = "",
    exp_month: Optional[str] = None,
    exp_year: Optional[str] = None,
    code: Optional[str] = "",
    favorite: Optional[bool] = False,
    folder_id: Optional[str] = "",
):
    item = bitwarden_get_item(session_code, id)
    raw_item = item.raw

    if name:
        raw_item["name"] = name

    if username:
        raw_item["login"]["username"] = username
    if password:
        raw_item["login"]["password"] = password
    if notes:
        raw_item["notes"] = notes
    if totp:
        raw_item["login"]["totp"] = totp
    if cardholder_name:
        raw_item["card"]["cardholderName"] = cardholder_name
    if brand:
        raw_item["card"]["brand"] = brand
    if number:
        raw_item["card"]["number"] = number
    if exp_month:
        raw_item["card"]["expMonth"] = str(int(exp_month))
    if exp_year:
        raw_item["card"]["expYear"] = str(int(exp_year))
    if code:
        raw_item["card"]["code"] = code
    if favorite is not None:
        raw_item["favorite"] = favorite
    if folder_id:
        raw_item["folderId"] = folder_id
    else:
        raw_item["folderId"] = None

    try:
        run_bw(
            ["edit", "item", id, b64encode(json.dumps(raw_item).encode()).decode()], env={"BW_SESSION": session_code}
        )
    except Exception as e:
        return BitwardenClientResponse(success=False, data=str(e))
    return BitwardenClientResponse(success=True, data="")


def bitwarden_sync(session_code: str) -> BitwardenClientResponse:
    try:
        result = run_bw(["sync"], env={"BW_SESSION": session_code})
    except Exception as e:
        return BitwardenClientResponse(success=False, data=str(e))
    return BitwardenClientResponse(success=True, data=result.data)


def bitwarden_set_server(url: str) -> BitwardenClientResponse:
    try:
        result = run_bw(["config", "server", url])
    except Exception as e:
        return BitwardenClientResponse(success=False, data=str(e))
    return BitwardenClientResponse(success=True, data=result.data)


def bitwarden_logout() -> BitwardenClientResponse:
    try:
        result = run_bw(["logout"])
    except Exception as e:
        return BitwardenClientResponse(success=False, data=str(e))
    return BitwardenClientResponse(success=True, data=result.data)


def bitwarden_delete_item(session_code: str, item_id: str, permanent: bool = False) -> BitwardenClientResponse:
    args = ["delete", "item", item_id]
    if permanent:
        args.append("--permanent")
    try:
        result = run_bw(args, env={"BW_SESSION": session_code})
    except Exception as e:
        return BitwardenClientResponse(success=False, data=str(e))
    return BitwardenClientResponse(success=True, data=result.data)


def bitwarden_restore_item(session_code: str, item_id: str) -> BitwardenClientResponse:
    args = ["restore", "item", item_id]
    try:
        result = run_bw(args, env={"BW_SESSION": session_code})
    except Exception as e:
        return BitwardenClientResponse(success=False, data=str(e))
    return BitwardenClientResponse(success=True, data=result.data)

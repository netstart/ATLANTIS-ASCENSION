"""Trava de release dos anúncios: confere o AAB de release já exportado e reprova se o build cairia no
modo "off" (sem anúncio, Ads.mode() == "off") em produção.

Portado do hyakki (tools/check_release_ads.py, mesmo autor), sem a parte de Play Billing, que este jogo
ainda não tem. O jogo só liga os anúncios em release quando (a) os IDs reais do AdMob estão no projeto
(AdMobProvider.has_release_ids(): RELEASE_UNITS em scripts/core/admob_provider.gd e
admob/general/android/app_id no project.godot) e (b) o singleton nativo "PoingGodotAdMob" existe no
Android (AdMobProvider.startup_provider()). Este script confere no pacote gerado:

- manifesto: meta-data com.google.android.gms.ads.APPLICATION_ID igual ao app_id do project.godot,
  e o app_id é real (ca-app-pub-, com "~", fora da conta de teste do Google);
- plugin Poing AdMob empacotado: meta-data org.godotengine.plugin.v2.PoingGodotAdMob (é por ela que
  o Godot registra o plugin v2 e cria o singleton) e a classe no dex, mais os plugins de
  recompensado e UMP que o jogo usa;
- Google Mobile Ads SDK (classes no dex e a AdActivity no manifesto) e UMP (classes no dex);
- permissões INTERNET e com.google.android.gms.permission.AD_ID;
- RELEASE_UNITS com bloco recompensado real (lido do repositório e, quando o script empacotado
  puder ser lido, também no .gdc do pacote) e o pacote não é depurável;
- versionName/versionCode do pacote iguais ao project.godot e ao export_presets.cfg
  (pacote mais velho reprova com "AAB desatualizado").

O manifesto do AAB é protobuf (base/manifest/AndroidManifest.xml); o do APK é XML binário. Os dois
são lidos aqui em Python puro, sem dependência nova. Precisa do pacote exportado, por isso roda em
tools/build_release.ps1 (logo depois do AAB) e não em tools/run_checks.ps1.

Uso: python -I tools/check_release_ads.py [pacote.aab|pacote.apk ...]
Sem argumentos confere build/atlantis-ascension-release.aab.
"""
from __future__ import annotations

import dataclasses
import pathlib
import re
import struct
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_ARTIFACTS = [ROOT / "build/atlantis-ascension-release.aab"]
PROVIDER = "scripts/core/admob_provider.gd"
# Preset de cada tipo de pacote (os dois Android têm a mesma versão; o APK de release não é gerado hoje).
PRESETS = {"aab": "Android Play", "apk": "Android"}

TEST_PUBLISHER = "ca-app-pub-3940256099942544"
APP_ID_META = "com.google.android.gms.ads.APPLICATION_ID"
PLUGIN_PREFIX = "org.godotengine.plugin.v2."
# Plugins v2 que o jogo usa: nome do singleton (meta-data) -> classe carregada por reflexão.
REQUIRED_PLUGINS = {
    "PoingGodotAdMob": "com.poingstudios.godot.admob.ads.PoingGodotAdMob",
    "PoingGodotAdMobRewardedAd": "com.poingstudios.godot.admob.ads.PoingGodotAdMobRewardedAd",
    "PoingGodotAdMobUserMessagingPlatform": "com.poingstudios.godot.admob.ads.PoingGodotAdMobUserMessagingPlatform",
    "PoingGodotAdMobConsentInformation": "com.poingstudios.godot.admob.ads.PoingGodotAdMobConsentInformation",
}
REQUIRED_PERMISSIONS = ["android.permission.INTERNET", "com.google.android.gms.permission.AD_ID"]
# Marcadores no dex: (descrição, prefixos aceitos). O R8 renomeia as classes internas, mas mantém os
# pacotes; os prefixos abaixo foram conferidos nos pacotes de release do hyakki 1.40.6 (mesmo plugin).
DEX_MARKERS = [
    ("Google Mobile Ads SDK", [b"Lcom/google/android/libraries/ads/mobile/sdk/", b"Lcom/google/android/gms/ads/"]),
    ("UMP (User Messaging Platform)", [b"Lcom/google/android/ump/", b"Lcom/google/android/gms/internal/consent_sdk/"]),
]
AD_ACTIVITIES = ["com.google.android.libraries.ads.mobile.sdk.common.AdActivity",
                 "com.google.android.gms.ads.AdActivity"]

# IDs de recurso dos atributos android: (para manifestos sem nome de atributo no pool de strings).
ANDROID_ATTR_IDS = {0x01010003: "name", 0x01010024: "value", 0x0101000F: "debuggable",
                    0x0101021B: "versionCode", 0x0101021C: "versionName"}


# --- Árvore XML comum aos dois formatos -------------------------------------------------------

@dataclasses.dataclass
class Element:
    tag: str
    attrs: dict = dataclasses.field(default_factory=dict)
    children: list = dataclasses.field(default_factory=list)

    def iter(self, tag: str | None = None):
        if tag is None or self.tag == tag:
            yield self
        for c in self.children:
            yield from c.iter(tag)


# --- XML binário do APK (AXML) ----------------------------------------------------------------

def _read_string_pool(data: bytes, start: int) -> list[str]:
    _t, header_size, _size = struct.unpack_from("<HHI", data, start)
    count, _styles, flags, strings_start, _styles_start = struct.unpack_from("<IIIII", data, start + 8)
    utf8 = bool(flags & 0x100)
    offsets = struct.unpack_from(f"<{count}I", data, start + header_size)
    base = start + strings_start
    out = []
    for off in offsets:
        p = base + off
        if utf8:
            for _ in range(2):  # tamanho em UTF-16 e depois em bytes UTF-8
                n = data[p]
                p += 1
                if n & 0x80:
                    n = ((n & 0x7F) << 8) | data[p]
                    p += 1
            out.append(data[p:p + n].decode("utf-8", "replace"))
        else:
            n = struct.unpack_from("<H", data, p)[0]
            p += 2
            if n & 0x8000:
                n = ((n & 0x7FFF) << 16) | struct.unpack_from("<H", data, p)[0]
                p += 2
            out.append(data[p:p + 2 * n].decode("utf-16-le", "replace"))
    return out


def _typed_value(data_type: int, value: int, strings: list[str]) -> str:
    if data_type == 0x03:
        return strings[value] if value < len(strings) else ""
    if data_type == 0x10:
        return str(struct.unpack("<i", struct.pack("<I", value))[0])
    if data_type == 0x11:
        return hex(value)
    if data_type == 0x12:
        return "true" if value else "false"
    if data_type == 0x01:
        return f"@0x{value:08x}"
    return str(value)


def parse_axml(data: bytes) -> Element:
    """Lê o AndroidManifest.xml binário de um APK."""
    if len(data) < 8 or struct.unpack_from("<H", data, 0)[0] != 0x0003:
        raise ValueError("não é XML binário do Android")
    _t, header_size, total = struct.unpack_from("<HHI", data, 0)
    strings: list[str] = []
    res_ids: list[int] = []
    stack: list[Element] = []
    root: Element | None = None
    p = header_size
    while p + 8 <= min(total, len(data)):
        ctype, chsize, csize = struct.unpack_from("<HHI", data, p)
        if csize < 8:
            break
        if ctype == 0x0001:
            strings = _read_string_pool(data, p)
        elif ctype == 0x0180:
            res_ids = list(struct.unpack_from(f"<{(csize - chsize) // 4}I", data, p + chsize))
        elif ctype == 0x0102:
            ext = p + chsize
            _ns, name, attr_start, attr_size, attr_count = struct.unpack_from("<IIHHH", data, ext)
            el = Element(strings[name] if name < len(strings) else "")
            for i in range(attr_count):
                a = ext + attr_start + i * attr_size
                _ans, aname, raw, _vsize, _res0, dtype, dval = struct.unpack_from("<IIIHBBI", data, a)
                key = strings[aname] if aname < len(strings) else ""
                if not key and aname < len(res_ids):
                    key = ANDROID_ATTR_IDS.get(res_ids[aname], "")
                if raw != 0xFFFFFFFF and raw < len(strings):
                    val = strings[raw]
                else:
                    val = _typed_value(dtype, dval, strings)
                el.attrs[key] = val
            if stack:
                stack[-1].children.append(el)
            else:
                root = el
            stack.append(el)
        elif ctype == 0x0103:
            if stack:
                stack.pop()
        p += csize
    if root is None:
        raise ValueError("manifesto binário sem elemento raiz")
    return root


# --- XML em protobuf do AAB (aapt2 Resources.proto: XmlNode) ----------------------------------

def _varint(data: bytes, p: int) -> tuple[int, int]:
    result = shift = 0
    while True:
        b = data[p]
        p += 1
        result |= (b & 0x7F) << shift
        if not b & 0x80:
            return result, p
        shift += 7


def _fields(data: bytes):
    """(número do campo, tipo, valor) de uma mensagem protobuf."""
    p = 0
    while p < len(data):
        key, p = _varint(data, p)
        num, wire = key >> 3, key & 7
        if wire == 0:
            val, p = _varint(data, p)
        elif wire == 1:
            val, p = data[p:p + 8], p + 8
        elif wire == 2:
            n, p = _varint(data, p)
            val, p = data[p:p + n], p + n
        elif wire == 5:
            val, p = data[p:p + 4], p + 4
        else:
            raise ValueError(f"protobuf com tipo de campo {wire} inesperado")
        yield num, wire, val


def _proto_item_value(item: bytes) -> str:
    for num, _w, val in _fields(item):
        if num in (2, 3):  # String / RawString { string value = 1; }
            for n2, _w2, v2 in _fields(val):
                if n2 == 1:
                    return v2.decode("utf-8", "replace")
        if num == 7:  # Primitive
            for n2, _w2, v2 in _fields(val):
                if n2 == 6:
                    return str(struct.unpack("<i", struct.pack("<I", v2 & 0xFFFFFFFF))[0])
                if n2 == 7:
                    return hex(v2)
                if n2 == 8:
                    return "true" if v2 else "false"
    return ""


def _proto_element(data: bytes) -> Element:
    el = Element("")
    for num, _w, val in _fields(data):
        if num == 3:
            el.tag = val.decode("utf-8", "replace")
        elif num == 4:
            name, value, res_id, compiled = "", "", 0, b""
            for n2, _w2, v2 in _fields(val):
                if n2 == 2:
                    name = v2.decode("utf-8", "replace")
                elif n2 == 3:
                    value = v2.decode("utf-8", "replace")
                elif n2 == 5:
                    res_id = v2
                elif n2 == 6:
                    compiled = v2
            if not name:
                name = ANDROID_ATTR_IDS.get(res_id, "")
            if not value and compiled:
                value = _proto_item_value(compiled)
            el.attrs[name] = value
        elif num == 5:
            child = _proto_node(val)
            if child is not None:
                el.children.append(child)
    return el


def _proto_node(data: bytes) -> Element | None:
    for num, _w, val in _fields(data):
        if num == 1:
            return _proto_element(val)
    return None


def parse_proto_xml(data: bytes) -> Element:
    """Lê o AndroidManifest.xml em protobuf de um AAB."""
    root = _proto_node(data)
    if root is None or not root.tag:
        raise ValueError("manifesto protobuf sem elemento raiz")
    return root


# --- Informações do manifesto -----------------------------------------------------------------

@dataclasses.dataclass
class ManifestInfo:
    package: str = ""
    version_code: str = ""
    version_name: str = ""
    permissions: set = dataclasses.field(default_factory=set)
    meta: dict = dataclasses.field(default_factory=dict)  # meta-data dentro de <application>
    activities: set = dataclasses.field(default_factory=set)
    debuggable: bool = False


def manifest_info(root: Element) -> ManifestInfo:
    info = ManifestInfo(package=root.attrs.get("package", ""),
                        version_code=root.attrs.get("versionCode", ""),
                        version_name=root.attrs.get("versionName", ""))
    for el in root.iter("uses-permission"):
        info.permissions.add(el.attrs.get("name", ""))
    for app in root.iter("application"):
        info.debuggable = info.debuggable or app.attrs.get("debuggable", "").lower() == "true"
        for el in app.children:
            if el.tag == "meta-data":
                info.meta[el.attrs.get("name", "")] = el.attrs.get("value", "")
            elif el.tag in ("activity", "activity-alias"):
                info.activities.add(el.attrs.get("name", ""))
    return info


# --- Configuração do repositório --------------------------------------------------------------

@dataclasses.dataclass
class Expected:
    app_id: str
    version_name: str
    preset_versions: dict  # "aab"/"apk" -> (name, code)
    release_units: dict


def _cfg_sections(text: str) -> list[tuple[str, str]]:
    parts = re.split(r"^\[([^\]]+)\]\s*$", text, flags=re.M)
    return [(parts[i], parts[i + 1]) for i in range(1, len(parts) - 1, 2)]


def parse_project_godot(text: str) -> tuple[str, str]:
    """(app_id do AdMob, config/version) do project.godot."""
    app_id = version = ""
    for section, body in _cfg_sections(text):
        if section == "admob":
            m = re.search(r'^general/android/app_id="([^"]*)"', body, re.M)
            app_id = m.group(1) if m else app_id
        elif section == "application":
            m = re.search(r'^config/version="([^"]*)"', body, re.M)
            version = m.group(1) if m else version
    return app_id, version


def parse_export_presets(text: str) -> dict:
    """{nome do preset: (version/name, version/code)} do export_presets.cfg."""
    out = {}
    sections = _cfg_sections(text)
    for i, (section, body) in enumerate(sections):
        if not re.fullmatch(r"preset\.\d+", section):
            continue
        name = re.search(r'^name="([^"]*)"', body, re.M)
        options = sections[i + 1][1] if i + 1 < len(sections) and sections[i + 1][0] == f"{section}.options" else ""
        vname = re.search(r'^version/name="([^"]*)"', options, re.M)
        vcode = re.search(r"^version/code=(\d+)", options, re.M)
        if name:
            out[name.group(1)] = (vname.group(1) if vname else "", vcode.group(1) if vcode else "")
    return out


def parse_release_units(gd_text: str) -> dict:
    """RELEASE_UNITS de scripts/core/admob_provider.gd."""
    m = re.search(r"const\s+RELEASE_UNITS\s*:?=\s*\{(.*?)\}", gd_text, re.S)
    if not m:
        return {}
    return dict(re.findall(r'"(\w+)"\s*:\s*"([^"]*)"', m.group(1)))


def is_real_id(ad_id: str, separator: str) -> bool:
    """Mesma regra de AdMobProvider._is_real_id()."""
    ad_id = ad_id.strip()
    return ad_id.startswith("ca-app-pub-") and separator in ad_id and not ad_id.startswith(TEST_PUBLISHER)


def load_expected(root: pathlib.Path = ROOT) -> Expected:
    app_id, version = parse_project_godot((root / "project.godot").read_text(encoding="utf-8"))
    presets = parse_export_presets((root / "export_presets.cfg").read_text(encoding="utf-8"))
    units = parse_release_units((root / PROVIDER).read_text(encoding="utf-8"))
    return Expected(app_id=app_id, version_name=version,
                    preset_versions={k: presets.get(v, ("", "")) for k, v in PRESETS.items()},
                    release_units=units)


# --- Leitura do pacote ------------------------------------------------------------------------

@dataclasses.dataclass
class Artifact:
    kind: str  # "aab" ou "apk"
    manifest: ManifestInfo
    dex: list  # bytes de cada classes*.dex
    provider_script: bytes | None = None  # admob_provider.gdc/.gd empacotado (descomprimido)


def _decode_gdc(data: bytes) -> bytes | None:
    """Conteúdo do script empacotado; None se ele vier comprimido e não der para abrir."""
    if not data.startswith(b"GDSC"):
        return data
    body = data[12:]
    if not body.startswith(b"\x28\xb5\x2f\xfd"):
        return body
    try:
        from compression import zstd  # Python 3.14+
    except ImportError:
        return None
    try:
        return zstd.decompress(body)
    except Exception:  # noqa: BLE001 - formato novo do Godot: tratado como "não deu para ler"
        return None


def read_artifact(path: pathlib.Path) -> Artifact:
    kind = "aab" if path.suffix.lower() == ".aab" else "apk"
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        if kind == "aab":
            manifest = manifest_info(parse_proto_xml(z.read("base/manifest/AndroidManifest.xml")))
            dex_names = [n for n in names if re.fullmatch(r"base/dex/classes\d*\.dex", n)]
        else:
            manifest = manifest_info(parse_axml(z.read("AndroidManifest.xml")))
            dex_names = [n for n in names if re.fullmatch(r"classes\d*\.dex", n)]
        dex = [z.read(n) for n in dex_names]
        script = None
        for suffix in (PROVIDER + "c", PROVIDER):
            found = [n for n in names if n.endswith("assets/" + suffix)]
            if found:
                script = _decode_gdc(z.read(found[0]))
                break
    return Artifact(kind=kind, manifest=manifest, dex=dex, provider_script=script)


# --- Regras (puras) ---------------------------------------------------------------------------

def check_artifact(art: Artifact, exp: Expected) -> tuple[list[str], list[str]]:
    """(erros, avisos) do pacote contra o projeto."""
    errors: list[str] = []
    warnings: list[str] = []
    label = art.kind.upper()
    m = art.manifest

    # Versão: pacote velho é o erro mais comum (export esquecido depois do bump).
    want_name, want_code = exp.preset_versions.get(art.kind, ("", ""))
    if not want_code:
        errors.append(f"export_presets.cfg sem version/code no preset '{PRESETS[art.kind]}'")
    if want_name and exp.version_name and want_name != exp.version_name:
        errors.append(f"versão do preset '{PRESETS[art.kind]}' ({want_name}) difere do project.godot ({exp.version_name})")
    try:
        got_code = int(m.version_code)
    except ValueError:
        got_code = -1
        errors.append(f"{label} sem versionCode legível no manifesto")
    if want_code and got_code >= 0:
        if got_code < int(want_code):
            errors.append(f"{label} desatualizado: o pacote é {m.version_name} (versionCode {got_code}), "
                          f"o projeto está em {want_name} (versionCode {want_code}); exporte de novo")
        elif got_code != int(want_code) or m.version_name != want_name:
            errors.append(f"versão do {label} ({m.version_name}, versionCode {got_code}) difere do projeto "
                          f"({want_name}, versionCode {want_code})")

    # ID do app AdMob.
    if not is_real_id(exp.app_id, "~"):
        errors.append(f"admob/general/android/app_id do project.godot não é um ID real: '{exp.app_id}'")
    got_app_id = m.meta.get(APP_ID_META)
    if got_app_id is None:
        errors.append(f"manifesto do {label} sem meta-data {APP_ID_META} (o SDK de anúncios não inicia)")
    elif got_app_id != exp.app_id:
        errors.append(f"{APP_ID_META} do {label} ('{got_app_id}') difere do project.godot ('{exp.app_id}')")
    elif not is_real_id(got_app_id, "~"):
        errors.append(f"{APP_ID_META} do {label} não é um ID real: '{got_app_id}'")

    # Blocos de anúncio.
    rewarded = exp.release_units.get("rewarded", "")
    if not is_real_id(rewarded, "/"):
        errors.append(f"RELEASE_UNITS de {PROVIDER} sem bloco recompensado real: '{rewarded}'")
    if art.provider_script is None:
        warnings.append(f"não deu para ler o admob_provider empacotado no {label}; RELEASE_UNITS conferido só no repositório")
    elif rewarded and rewarded.encode("utf-8") not in art.provider_script:
        errors.append(f"o admob_provider empacotado no {label} não tem o bloco recompensado '{rewarded}'")

    # Plugins v2 (o Godot cria os singletons a partir destas meta-data) e suas classes no dex.
    dex = art.dex
    for plugin, cls in REQUIRED_PLUGINS.items():
        key = PLUGIN_PREFIX + plugin
        if m.meta.get(key) != cls:
            errors.append(f"plugin {plugin} fora do {label}: manifesto sem meta-data {key} = {cls}")
        marker = ("L" + cls.replace(".", "/") + ";").encode()
        if not any(marker in d for d in dex):
            errors.append(f"classe {cls} (plugin {plugin}) não está no dex do {label}")
    for desc, prefixes in DEX_MARKERS:
        if not any(p in d for d in dex for p in prefixes):
            errors.append(f"{desc} não está no dex do {label}")
    if not any(a in m.activities for a in AD_ACTIVITIES):
        errors.append(f"manifesto do {label} sem a AdActivity do Google Mobile Ads SDK")

    for perm in REQUIRED_PERMISSIONS:
        if perm not in m.permissions:
            errors.append(f"manifesto do {label} sem a permissão {perm}")
    if m.debuggable:
        errors.append(f"{label} é depurável (android:debuggable=true): não é build de release")
    return errors, warnings


# --- Linha de comando -------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    paths = [pathlib.Path(a) for a in argv] or DEFAULT_ARTIFACTS
    try:
        exp = load_expected()
    except OSError as e:
        print(f"FALHOU: não li a configuração do projeto: {e}")
        return 1
    failed = False
    for path in paths:
        print(f"== {path}")
        if not path.is_file():
            print(f"FALHOU: {path} não existe (exporte o release antes)")
            failed = True
            continue
        try:
            art = read_artifact(path)
        except (OSError, KeyError, ValueError, IndexError, struct.error, zipfile.BadZipFile) as e:
            print(f"FALHOU: não consegui ler {path}: {e}")
            failed = True
            continue
        errors, warnings = check_artifact(art, exp)
        for w in warnings:
            print(f"aviso: {w}")
        for e in errors:
            print(f"FALHOU: {e}")
        if errors:
            failed = True
        else:
            m = art.manifest
            print(f"ok: {m.package} {m.version_name} (versionCode {m.version_code}), anúncio recompensado ligado")
    if failed:
        print("Release REPROVADO: este pacote abriria no modo \"sem anúncios\" ou está desatualizado. Não envie.")
        return 1
    print("Release aprovado: anúncio recompensado (AdMob + UMP) no pacote.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

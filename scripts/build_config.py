"""Parse build inputs and resolve one immutable image/Compose configuration."""
import argparse
import json
from dataclasses import dataclass, replace
from datetime import datetime
import os
import tempfile
from pathlib import Path, PurePosixPath
import re
import secrets
import string

ROOT = Path(__file__).resolve().parents[1]
# The pinned desktop dependency's x11 image matrix.
SYSTEMS = {
    "debian": ("trixie", "debian", ("bookworm", "trixie")),
    "ubuntu": ("noble", "ubuntu", ("jammy", "noble")),
    "fedora": ("43", "user", ("41", "42", "43", "44")),
    "alpine": ("latest", "alpine", ("3.21", "3.22", "latest")),
}
DESKTOPS = ("xfce", "lxqt", "mate")
CN_TIMEZONES = {"Asia/Shanghai", "Asia/Chongqing", "Asia/Chungking", "Asia/Harbin", "Asia/Urumqi", "PRC"}


def argument_parser():
    parser = argparse.ArgumentParser(description="Build, publish, start, or stop Android desktop images.")
    for short, name, help_text in (
        ("-b", "build", "Build the pinned desktop dependency and Android image"),
        ("-P", "publish", "Build and publish both architectures (requires a namespace)"),
        ("-S", "start", "Start the resolved image with Compose"),
        ("-T", "stop", "Stop the Compose project"),
        ("-c", "create-env", "Interactively update configuration"),
        ("-m", "multi-arch", "Use both architectures when publishing"),
    ):
        parser.add_argument(short, "--" + name, action="store_true", help=help_text)
    parser.add_argument("--jdk-provider", choices=("openjdk", "temurin"))
    parser.add_argument("-j", "--jdk-version")
    parser.add_argument("-s", "--system", choices=tuple(SYSTEMS))
    parser.add_argument("-v", "--version")
    parser.add_argument("-d", "--desktop", choices=DESKTOPS)
    parser.add_argument("-z", "--timezone")
    parser.add_argument("-p", "--password")
    parser.add_argument("--namespace", help="Docker image namespace; empty uses local images")
    parser.add_argument("--config", type=Path, default=ROOT / ".env", help="Configuration file (default: repository .env)")
    parser.add_argument("--project-name", help="Optional isolated Compose project name")
    parser.add_argument("--desktop-image", help="Use an existing desktop image instead of building the dependency")
    parser.add_argument("--latest", action="store_true")
    parser.add_argument("--no-snapshot", action="store_true")
    mirror = parser.add_mutually_exclusive_group()
    mirror.add_argument("--cn-mirror", dest="china", action="store_true")
    mirror.add_argument("--no-cn-mirror", dest="china", action="store_false")
    parser.set_defaults(china=None)
    parser.add_argument("--completion", choices=("options", "system", "version", "desktop", "jdk-provider", "jdk-version"), help=argparse.SUPPRESS)
    return parser


def read_env(path):
    """Read literal dotenv assignments; never execute shell expressions."""
    values = {}
    if not path.exists():
        return values
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        match = re.fullmatch(r"(?:export )?([A-Za-z_][A-Za-z0-9_]*)=(.*)", line)
        if not match:
            raise ValueError(f"Invalid configuration assignment at {path}:{number}")
        key, value = match.groups()
        value = value.strip()
        if value.startswith("'"):
            quoted = re.fullmatch(r"'((?:\\.|[^'])*)'\s*(?:#.*)?", value)
            if not quoted:
                raise ValueError(f"Invalid quoted value at {path}:{number}")
            value = quoted.group(1).replace("\\'", "'")
        elif value.startswith('"'):
            value, end = json.JSONDecoder().raw_decode(value)
            trailing = match.group(2).strip()[end:].strip()
            if trailing and not trailing.startswith("#"):
                raise ValueError(f"Unexpected text after quoted value at {path}:{number}")
            value = value.replace("$$", "$")
        else:
            value = value.split(" #", 1)[0].rstrip()
        values[key] = value
    return values


def write_env(path, values):
    """Persist literal values in Compose-compatible dotenv syntax."""
    lines = []
    for key, value in values.items():
        value = str(value)
        if "\n" in value or "\r" in value:
            raise ValueError(f"Configuration value {key} must fit on one line")
        encoded = json.dumps(value, ensure_ascii=False).replace("$", "$$")
        lines.append(f"{key}={encoded}\n")
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, prefix=".build-env-", delete=False) as output:
            temporary = Path(output.name)
            output.write("".join(lines))
        temporary.chmod(0o600)
        temporary.replace(path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)



def host_timezone():
    zone = os.environ.get("TZ")
    if zone:
        return zone
    path = Path("/etc/timezone")
    if path.exists():
        return path.read_text().strip()
    localtime = Path("/etc/localtime").resolve().as_posix()
    return localtime.split("/zoneinfo/", 1)[-1] if "/zoneinfo/" in localtime else "UTC"


@dataclass(frozen=True)
class BuildConfig:
    system: str
    version: str
    desktop: str
    provider: str
    jdk: str
    namespace: str
    timestamp: str
    timezone: str
    china: bool
    password: str
    latest: bool
    snapshot: bool

    @property
    def user(self):
        return SYSTEMS[self.system][1]

    @property
    def home(self):
        return f"/home/{self.user}"

    @property
    def repository(self):
        return f"{self.namespace}/android-in-docker" if self.namespace else "android-in-docker"

    @property
    def prefix(self):
        return f"{self.system}-{self.version}-{self.desktop}-{self.provider}{self.jdk}" + ("-cn" if self.china else "")

    @property
    def image_ref(self):
        return f"{self.repository}:{self.prefix}-{self.timestamp}"

    @property
    def desktop_image(self):
        namespace = f"{self.namespace}/" if self.namespace else ""
        region = "-cn" if self.china else ""
        return f"{namespace}desktop-in-docker:{self.system}-{self.version}-{self.desktop}{region}-{self.timestamp}"

    def tags(self):
        short = []
        if self.system != "debian":
            short.append(self.system)
        if self.version != SYSTEMS[self.system][0]:
            short.append(self.version)
        if self.desktop != "xfce":
            short.append(self.desktop)
        if (self.provider, self.jdk) != ("openjdk", "21"):
            short.append(self.provider + self.jdk)
        if self.china:
            short.append("cn")
        prefixes = (self.prefix, "-".join(short))
        labels = (self.timestamp,) + (("latest",) if self.latest else ()) + (("snapshot",) if self.snapshot else ())
        return tuple(dict.fromkeys(f"{self.repository}:{prefix + '-' if prefix else ''}{label}" for prefix in prefixes for label in labels))

    def persisted(self):
        return dict(DOCKER_USERNAME=self.namespace, BASE_SYSTEM=self.system, BASE_VERSION=self.version,
                    DESKTOP_TYPE=self.desktop, JDK_PROVIDER=self.provider, OPENJDK_VERSION=self.jdk,
                    TZ=self.timezone, USE_CN_ENV=str(self.china).lower(), VNC_PASSWD=self.password,
                    IMAGE_TAG_TIME=self.timestamp, IMAGE_REF=self.image_ref, CONTAINER_HOME=self.home, CONTAINER_USER=self.user)


def resolve_config(args, saved, environ=None):
    env = {**saved, **(os.environ if environ is None else environ)}
    def choose(value, key, default):
        return value if value is not None else env.get(key) or default
    system = choose(args.system, "BASE_SYSTEM", "debian")
    if system not in SYSTEMS:
        raise ValueError(f"Unsupported base system: {system}")
    version = SYSTEMS[system][0] if args.system and args.system != env.get("BASE_SYSTEM") and args.version is None else choose(args.version, "BASE_VERSION", SYSTEMS[system][0])
    desktop = choose(args.desktop, "DESKTOP_TYPE", "xfce")
    provider = choose(args.jdk_provider, "JDK_PROVIDER", "openjdk")
    jdk = choose(args.jdk_version, "OPENJDK_VERSION", "21")
    namespace = choose(args.namespace, "DOCKER_USERNAME", "")
    timestamp = env.get("IMAGE_TAG_TIME", "")
    if not re.fullmatch(r"[0-9]{12,14}", timestamp):
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    timezone = choose(args.timezone, "TZ", host_timezone())
    if args.china is not None:
        china = args.china
    elif args.timezone is not None:
        china = timezone in CN_TIMEZONES
    elif env.get("USE_CN_ENV") in ("true", "false"):
        china = env["USE_CN_ENV"] == "true"
    else:
        china = timezone in CN_TIMEZONES
    config = BuildConfig(system, version, desktop, provider, jdk, namespace, timestamp, timezone, china,
                         choose(args.password, "VNC_PASSWD", "password"), args.latest, not args.no_snapshot)
    validate_image_config(config)
    return config


def validate_image_config(config):
    """Validate syntax independently of current distribution package availability."""
    for name, value in (("version", config.version), ("desktop", config.desktop)):
        if not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.-]*", value):
            raise ValueError(f"Invalid {name}: {value!r}")
    if config.provider not in ("openjdk", "temurin") or not re.fullmatch(r"[0-9]+", config.jdk):
        raise ValueError("Invalid Java provider or JDK version")
    if config.namespace and not re.fullmatch(r"[a-z0-9][a-z0-9_.-]*(?:/[a-z0-9][a-z0-9_.-]*)*", config.namespace):
        raise ValueError("Namespace must use lowercase Docker repository components")
    if any("\n" in value or "\r" in value for value in config.persisted().values()):
        raise ValueError("Configuration values must fit on one line")


def validate_build_config(config, *, publish=False):
    """Validate the final recipe before saving it or starting any build."""
    validate_image_config(config)
    if config.version not in SYSTEMS[config.system][2]:
        raise ValueError(f"Unsupported base version {config.version!r} for {config.system}")
    if config.desktop not in DESKTOPS:
        raise ValueError(f"Unsupported desktop: {config.desktop}")
    if config.system == "fedora" and int(config.version) >= 44 and config.provider == "openjdk" and config.jdk == "21":
        raise ValueError("Fedora 44 no longer ships OpenJDK 21; use --jdk-provider temurin or --jdk-version 25")
    if publish and not config.namespace:
        raise ValueError("Publishing requires --namespace or DOCKER_USERNAME")


@dataclass(frozen=True)
class RuntimeConfig:
    image_ref: str
    home: str
    user: str
    password: str
    timezone: str

    @classmethod
    def from_build(cls, config):
        return cls(config.image_ref, config.home, config.user, config.password, config.timezone)

    def persisted(self):
        return dict(IMAGE_REF=self.image_ref, CONTAINER_HOME=self.home, CONTAINER_USER=self.user,
                    VNC_PASSWD=self.password, TZ=self.timezone)


def resolve_runtime_config(args, saved, environ=None):
    """Use the recorded artifact without rechecking the recipe that produced it."""
    env = {**saved, **(os.environ if environ is None else environ)}
    image_options = (args.system, args.version, args.desktop, args.jdk_provider, args.jdk_version, args.namespace, args.china)
    reference = env.get("IMAGE_REF")
    if not reference or any(value is not None for value in image_options):
        return RuntimeConfig.from_build(resolve_config(args, saved, environ))
    if any(character.isspace() for character in reference):
        raise ValueError("IMAGE_REF must not contain whitespace")
    system_user = SYSTEMS.get(env.get("BASE_SYSTEM", "debian"), (None, "debian", ()))[1]
    home = env.get("CONTAINER_HOME") or f"/home/{system_user}"
    if not PurePosixPath(home).is_absolute() or "\n" in home or "\r" in home:
        raise ValueError("CONTAINER_HOME must be an absolute container path")
    user = env.get("CONTAINER_USER") or PurePosixPath(home).name
    password = args.password if args.password is not None else env.get("VNC_PASSWD") or "password"
    timezone = args.timezone if args.timezone is not None else env.get("TZ") or host_timezone()
    return RuntimeConfig(reference, home, user, password, timezone)


def prompt_config(config):
    jdk = input(f"JDK version [{config.jdk}]: ").strip() or config.jdk
    password = input("VNC password [keep existing; r generates a random password]: ") or config.password
    if password == "r":
        password = "".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(16))
    namespace = input(f"Docker namespace [{config.namespace or 'local images'}]: ").strip() or config.namespace
    return replace(config, jdk=jdk, password=password, namespace=namespace,
                   timestamp=datetime.now().strftime("%Y%m%d%H%M%S"))

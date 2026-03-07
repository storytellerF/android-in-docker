# Docker Image Package Dependencies Documentation

**Generated**: 2024
**System**: Debian/Ubuntu Trixie

This document provides comprehensive dependency analysis for all packages installed in the Android-in-Docker image.

## Table of Contents

- [Overview](#overview)
- [Packages Details](#packages-details)
- [Dependency Statistics](#dependency-statistics)
- [Common Patterns](#common-patterns)

---

## Overview

The following **13 primary packages** are directly installed in the Dockerfile:

- `dbus-x11`
- `supervisor`
- `tightvncserver`
- `xfce4`
- `novnc`
- `openjdk-11-jdk`
- `wget`
- `unzip`
- `qemu-kvm`
- `elinks`
- `locales`
- `npm`
- `sudo`

---

## Packages Details


### dbus-x11

#### Package Information

**Description**: 

**Version**: 1.14.10-4ubuntu4.1
**Installed Size**: 144 KB

#### Required Dependencies (Depends)

```
dbus-bin (= 1.14.10-4ubuntu4.1)
dbus-daemon (= 1.14.10-4ubuntu4.1)
dbus-session-bus-common (>= 1.14.10-4ubuntu4.1)
libc6 (>= 2.38)
libdbus-1-3 (= 1.14.10-4ubuntu4.1)
libx11-6
```

#### Recommended Packages

None

#### Suggested Packages

None

---


### supervisor

#### Package Information

**Description**: 

**Version**: 4.2.5-1ubuntu0.1
**Installed Size**: 1678 KB

#### Required Dependencies (Depends)

```
lsb-base
python3-pkg-resources
python3:any
```

#### Recommended Packages

None

#### Suggested Packages

```
supervisor-doc
```

#### Pre-Dependencies

```
init-system-helpers (>= 1.54~)
```

---


### tightvncserver

#### Package Information

**Description**: 

**Version**: 1:1.3.10-8
**Installed Size**: 1730 KB

#### Required Dependencies (Depends)

```
tightvncpasswd (>= 1:1.3.10-7)
x11-common | xserver-common
x11-utils
xauth
perl:any
libc6 (>= 2.35)
libjpeg8 (>= 8c)
libx11-6
zlib1g (>= 1:1.1.4)
```

#### Recommended Packages

```
x11-xserver-utils
xfonts-base
```

#### Suggested Packages

```
tightvnc-java
```

---


### xfce4

#### Package Information

**Description**: 

**Version**: 4.18
**Installed Size**: 12 KB

#### Required Dependencies (Depends)

```
libxfce4ui-utils (>= 4.18.0)
thunar (>= 4.18.0)
xfce4-appfinder (>= 4.18.0)
xfce4-panel (>= 4.18.0)
xfce4-pulseaudio-plugin
xfce4-session (>= 4.18.0)
xfce4-settings (>= 4.18.0)
xfconf (>= 4.18.0)
xfdesktop4 (>= 4.18.0)
xfwm4 (>= 4.18.0)
```

#### Recommended Packages

```
desktop-base
tango-icon-theme
thunar-volman (>= 4.18.0)
xfce4-notifyd
xorg
```

#### Suggested Packages

```
xfce4-goodies
xfce4-power-manager (>= 4.18.0)
```

---


### novnc

#### Package Information

**Description**: 

**Version**: 1:1.3.0-2
**Installed Size**: 998 KB

#### Required Dependencies (Depends)

```
adduser
nodejs
net-tools
python3-novnc
python3-numpy
websockify
```

#### Recommended Packages

None

#### Suggested Packages

```
python-nova
```

---


### openjdk-11-jdk

#### Package Information

**Description**: 

**Version**: 11.0.30+7-1ubuntu1~24.04
**Installed Size**: 3098 KB

#### Required Dependencies (Depends)

```
openjdk-11-jre (= 11.0.30+7-1ubuntu1~24.04)
openjdk-11-jdk-headless (= 11.0.30+7-1ubuntu1~24.04)
libc6 (>= 2.34)
zlib1g (>= 1:1.1.4)
```

#### Recommended Packages

```
libxt-dev
```

#### Suggested Packages

```
openjdk-11-demo
openjdk-11-source
visualvm
```

---


### wget

#### Package Information

**Description**: 

**Version**: 1.21.4-1ubuntu4.1
**Installed Size**: 916 KB

#### Required Dependencies (Depends)

```
libc6 (>= 2.38)
libidn2-0 (>= 0.6)
libpcre2-8-0 (>= 10.22)
libpsl5t64 (>= 0.16.0)
libssl3t64 (>= 3.0.0)
libuuid1 (>= 2.16)
zlib1g (>= 1:1.1.4)
```

#### Recommended Packages

```
ca-certificates
```

#### Suggested Packages

None

---


### unzip

#### Package Information

**Description**: 

**Version**: 6.0-28ubuntu4.1
**Installed Size**: 375 KB

#### Required Dependencies (Depends)

```
libbz2-1.0
libc6 (>= 2.34)
```

#### Recommended Packages

None

#### Suggested Packages

```
zip
```

---


### qemu-kvm

#### Package Information

**Description**: 

**Version**: 

#### Required Dependencies (Depends)

None

#### Recommended Packages

None

#### Suggested Packages

None

---


### elinks

#### Package Information

**Description**: 

**Version**: 0.16.1.1-4.1ubuntu3
**Installed Size**: 1644 KB

#### Required Dependencies (Depends)

```
libbrotli1 (>= 0.6.0)
libbz2-1.0
libc6 (>= 2.38)
libev4t64 (>= 1:4.04)
libexpat1 (>= 2.0.1)
libfsplib0t64 (>= 0.9)
libgcrypt20 (>= 1.10.0)
libgnutls30t64 (>= 3.8.2)
libgpm2 (>= 1.20.7)
libgssapi-krb5-2 (>= 1.17)
libidn12 (>= 1.13)
liblua5.3-0
liblzma5 (>= 5.1.1alpha+20120614)
libperl5.38t64 (>= 5.38.2)
libtinfo6 (>= 6)
libtre5 (>= 0.8.0)
zlib1g (>= 1:1.1.4)
elinks-data (= 0.16.1.1-4.1ubuntu3)
```

#### Recommended Packages

None

#### Suggested Packages

```
elinks-doc
```

---


### locales

#### Package Information

**Description**: 

**Version**: 2.39-0ubuntu8.7
**Installed Size**: 16712 KB

#### Required Dependencies (Depends)

```
libc-bin (>> 2.39)
debconf (>= 0.5) | debconf-2.0
```

#### Recommended Packages

None

#### Suggested Packages

None

---


### npm

#### Package Information

**Description**: 

**Version**: 9.2.0~ds1-2
**Installed Size**: 2931 KB

#### Required Dependencies (Depends)

```
ca-certificates
node-abbrev
node-agent-base
node-aproba
node-archy
node-base64-js
node-binary-extensions
node-cacache (>= 17)
node-chalk (>= 5.1.2-2~)
node-chownr
node-ci-info
node-cli-table3
node-colors
node-columnify
node-cssesc
node-debug
node-depd
node-diff
node-emoji-regex
node-encoding
node-events
node-glob
node-got
node-graceful-fs
node-gyp
node-hosted-git-info (>= 6)
node-http-proxy-agent
node-https-proxy-agent
node-ieee754
node-ini
node-ip
node-ip-regex
node-json-parse-better-errors
node-jsonparse
node-lru-cache
node-minimatch
node-minipass
node-mkdirp
node-ms
node-negotiator
node-nopt
node-normalize-package-data
node-npm-bundled
node-npm-normalize-package-bin
node-npm-package-arg (>= 10)
node-npmlog
node-once
node-p-map
node-postcss-selector-parser
node-promise-retry
node-promzard
node-read
node-read-package-json
node-rimraf
node-semver
node-ssri
node-string-width
node-strip-ansi
node-tar
node-text-table
node-validate-npm-package-license
node-validate-npm-package-name
node-which
node-wrappy
node-write-file-atomic
node-yallist
nodejs:any
```

#### Recommended Packages

```
git
node-tap
```

#### Suggested Packages

```
node-opener
```

---


### sudo

#### Package Information

**Description**: 

**Version**: 1.9.15p5-3ubuntu5.24.04.1
**Installed Size**: 3468 KB

#### Required Dependencies (Depends)

```
libapparmor1 (>= 2.7.0~beta1+bzr1772)
libaudit1 (>= 1:2.2.1)
libc6 (>= 2.38)
libpam0g (>= 0.99.7.1)
libselinux1 (>= 3.1~)
libssl3t64 (>= 3.0.0)
zlib1g (>= 1:1.2.0.2)
libpam-modules
```

#### Recommended Packages

None

#### Suggested Packages

None

---


## Dependency Statistics

### Package Count

| Category | Count |
|----------|-------|
| Primary Packages | 13 |

### Dependency Summary

The following table provides a quick overview of which packages have recommendations and suggestions:

| Package | Has Recommends | Has Suggests |
|---------|---|---|
| dbus-x11 | ❌ | ❌ |
| supervisor | ❌ | ✓ |
| tightvncserver | ✓ | ✓ |
| xfce4 | ✓ | ✓ |
| novnc | ❌ | ✓ |
| openjdk-11-jdk | ✓ | ✓ |
| wget | ✓ | ❌ |
| unzip | ❌ | ✓ |
| qemu-kvm | ❌ | ❌ |
| elinks | ❌ | ✓ |
| locales | ❌ | ❌ |
| npm | ✓ | ✓ |
| sudo | ❌ | ❌ |

---

## Common Patterns

### Java Dependencies
- `openjdk-11-jdk` provides Java runtime and development tools
- Includes headless variant for server environments

### Desktop Environment (XFCE)
- `xfce4` is a lightweight desktop manager
- Includes panel, session manager, window manager, and file manager
- Recommended packages include icon themes and power management

### VNC & Display
- `tightvncserver` provides VNC server for remote display
- `novnc` provides web-based VNC access
- Both require X11 libraries

### Development Tools
- `npm` brings Node.js package management with extensive dependencies
- `wget` for downloading files
- `unzip` for archive extraction

---

## How to Use This Documentation

### For Docker Image Optimization
1. Review "Has Recommends" and "Has Suggests" columns
2. Consider removing `--no-install-recommends` flag to include recommended packages
3. Analyze if suggested packages are needed for your use case

### For Security Audits
1. Check all listed dependencies for CVEs
2. Focus on core libraries: libc6, openssl, zlib
3. Monitor Java and Node.js dependencies closely

### For License Compliance
1. Track all listed packages in your compliance matrix
2. Note packages with multiple alternatives (indicated by |)
3. Verify XFCE and related GUI components licenses

### For Space Reduction
1. Avoid suggested packages for minimal images
2. Use `--no-install-recommends` flag in apt-get
3. Consider multi-stage builds

---

## Technical Notes

1. **Dependency Extraction**: Using \`apt-cache show\` to parse package metadata
2. **Recommends vs Suggests**: 
   - Recommends: Packages that should normally be installed with this package
   - Suggests: Additional packages that may be useful
3. **Version Management**: OpenJDK version controlled via \`${OPENJDK_VERSION}\` build argument
4. **Alternative Dependencies**: Some packages have alternatives marked with \` | \`

---

*This documentation was automatically generated using improved dependency analysis script.*

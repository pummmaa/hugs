---
title: "guide-to-tar-complete"
date: 2026-08-15T18:33:10Z
lastmod: 2026-08-15T18:33:10Z
draft: false
tags: []
categories: []
series: []
summary: ""
ShowToc: true
TocOpen: true
weight: 10
---

# The Complete Guide to `tar`

`tar` (short for **t**ape **ar**chive) bundles many files and directories into a single archive file, optionally compressing it. It's the standard tool for backups, distributing source code, and moving directory trees around.

---

## 1. Mental Model: How `tar` Works

`tar` does **two separate jobs** that are often combined:

1. **Archiving** — packing many files into one `.tar` file (no compression by itself).
2. **Compression** — squeezing that archive with `gzip`, `bzip2`, `xz`, etc.

That's why you see extensions like:

| Extension | Meaning | Compression |
| --- | --- | --- |
| `.tar` | plain archive | none |
| `.tar.gz` / `.tgz` | gzip-compressed | fast, moderate ratio |
| `.tar.bz2` / `.tbz2` | bzip2-compressed | slower, better ratio |
| `.tar.xz` / `.txz` | xz-compressed | slowest, best ratio |
| `.tar.zst` | zstd-compressed | fast + great ratio (modern) |

---

## 2. The Core Flags

Almost every `tar` command is built from these:

| Flag | Long form | Meaning |
| --- | --- | --- |
| `-c` | `--create` | **C**reate a new archive |
| `-x` | `--extract` | e**X**tract files |
| `-t` | `--list` | Lis**t** contents |
| `-f` | `--file=ARCHIVE` | Use this archive **f**ile (almost always required) |
| `-v` | `--verbose` | **V**erbose — print each file processed |
| `-z` | `--gzip` | Filter through **gzip** (`.gz`) |
| `-j` | `--bzip2` | Filter through **bzip2** (`.bz2`) |
| `-J` | `--xz` | Filter through **xz** (`.xz`) |
| `-C` | `--directory=DIR` | **C**hange to directory before working |
| `-p` | `--preserve-permissions` | Keep file permissions |

> **Rule of thumb:** `-f` must come immediately before the archive name, because it consumes the next argument as the filename.
> 

---

## 3. The Commands You'll Actually Use

### Create archives

```bash
# Plain tar archive (no compression)
tar -cvf archive.tar file1 file2 dir/

# gzip-compressed (most common)
tar -czvf archive.tar.gz dir/

# bzip2-compressed
tar -cjvf archive.tar.bz2 dir/

# xz-compressed (best ratio)
tar -cJvf archive.tar.xz dir/
```

Mnemonic for creating a gzip archive: **"Create Ze Vile File"** → `czvf`.

### Extract archives

```bash
# Extract a .tar
tar -xvf archive.tar

# Extract .tar.gz  (modern tar auto-detects compression, so -z is optional)
tar -xzvf archive.tar.gz

# Extract .tar.bz2
tar -xjvf archive.tar.bz2

# Extract .tar.xz
tar -xJvf archive.tar.xz

# Extract into a specific directory
tar -xzvf archive.tar.gz -C /path/to/destination/
```

> On modern GNU tar and bsdtar you can usually just run `tar -xf archive.tar.*` and it detects the compression automatically.
> 

### List contents (without extracting)

```bash
tar -tvf archive.tar.gz          # list with details (perms, size, date)
tar -tf  archive.tar.gz          # just filenames
```

Always inspect an untrusted archive with `-t` **before** extracting.

---

## 4. Frequently Used Real-World Recipes

**Compress a whole directory, naming it cleanly:**

```bash
tar -czvf backup-$(date +%Y%m%d).tar.gz /home/ricardo/project
```

**Exclude files or folders:**

```bash
tar -czvf site.tar.gz /var/www \
    --exclude='*.log' \
    --exclude='node_modules' \
    --exclude='.git'
```

> Put `--exclude` **before** the source path for reliable behavior.
> 

**Extract a single file from a big archive:**

```bash
tar -xzvf archive.tar.gz path/inside/archive/file.txt
```

**Add files to an existing (uncompressed) archive:**

```bash
tar -rvf archive.tar newfile.txt        # -r = append; only works on uncompressed .tar
```

**Update only changed files:**

```bash
tar -uvf archive.tar dir/               # -u = append files newer than the copy in archive
```

**Strip leading path components on extract:**

```bash
tar -xzvf archive.tar.gz --strip-components=1
# Turns  project-v1.2/src/main.c  into  src/main.c
```

> Extremely handy for GitHub tarballs that wrap everything in one top folder.
> 

---

## 5. Power-User Techniques

**Pipe over SSH (backup a remote server with no temp file):**

```bash
# Pull a remote directory to a local archive
ssh user@host "tar -czf - /remote/dir" > backup.tar.gz

# Push a local directory into a remote server, extracting on arrival
tar -czf - localdir/ | ssh user@host "tar -xzf - -C /remote/dest"
```

**Copy a directory tree preserving all attributes (classic idiom):**

```bash
tar -cf - -C /src . | tar -xf - -C /dst
```

**Use a different compressor (e.g., zstd or parallel gzip):**

```bash
tar -c dir/ | zstd -o archive.tar.zst          # zstd
tar -cvf archive.tar.gz -I pigz dir/           # pigz = multi-core gzip, much faster
```

**Show a progress bar (with `pv`):**

```bash
tar -czf - dir/ | pv > archive.tar.gz
```

**List and count files in an archive:**

```bash
tar -tzf archive.tar.gz | wc -l
```

---

## 6. Common Pitfalls & Gotchas

- **Absolute paths:** GNU tar strips the leading `/` by default, storing paths as relative. This is a *safety feature* so extraction doesn't overwrite system files.
- **`-f` position matters:** `tar -cvzf archive.tar.gz` is fine, but `tar -cvfz archive.tar.gz` breaks because `z` gets treated as the filename.
- **You can't easily append to compressed archives:** `-r` and `-u` only work on uncompressed `.tar`. To modify a `.tar.gz`, decompress → modify → recompress.
- **Extraction overwrites by default** — no prompt. Use `-k` (`--keep-old-files`) to refuse overwriting existing files.
- **Preserve permissions when extracting as root:** use `-p`.
- **Beware "tar bombs":** archives that explode dozens of files into your current directory. Always `-t` first, or extract into a fresh subdirectory.

---

## 7. Quick Cheat Sheet

```bash
# CREATE
tar -czvf out.tar.gz dir/        # gzip
tar -cJvf out.tar.xz dir/        # xz (smallest)

# EXTRACT
tar -xzvf out.tar.gz             # to current dir
tar -xzvf out.tar.gz -C /dest    # to a target dir

# INSPECT
tar -tzvf out.tar.gz             # list contents

# The four you'll type 90% of the time:
#   tar -czvf   -> make a .tar.gz
#   tar -xzvf   -> unpack a .tar.gz
#   tar -tzvf   -> peek inside
#   tar -xf     -> unpack anything (auto-detect)
```

**Memory aids:**

- **c**reate, e**x**tract, lis**t** — pick exactly one.
- **"eXtract Ze Vile File"** = `xzvf`; **"Create Ze Vile File"** = `czvf`.
- Uppercase `-J` = xz, lowercase `-j` = bzip2 (easy to mix up).

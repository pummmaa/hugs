---
title: "Linux Networking"
date: 2026-08-07
lastmod: 2026-08-07
draft: false
tags: ["linux", "networking", "tcp/ip"]
categories: ["linux"]
series: ["Linux Fundamentals"]
weight: 1
summary: "Essential Linux networking commands and configuration"
ShowToc: true
TocOpen: true
---

## IP Configuration

```bash
ip addr show
ip route show
sudo ip route add 10.0.0.0/24 via 192.168.1.1


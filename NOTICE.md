# NOTICE: Upstream Projects and Licenses

This repository contains only original glue: the build and launcher scripts (`build.sh`, `run.sh`) and documentation. It distributes no upstream code. `build.sh` clones the projects below at install time, at the pinned commits, and builds them locally. The binaries you build carry their own upstream licenses, which are summarized here from the license files in the upstream trees as cloned on 2026-11-04.

## openvpn-tunpipe (the patched OpenVPN client)

- Project: ValdikSS/openvpn-tunpipe, a fork of OpenVPN adding a pipe device (`--dev "|<program>"`) so raw IP packets can be handed to a userspace program instead of a kernel tunnel device.
- Repository: https://github.com/ValdikSS/openvpn-tunpipe
- Pinned: branch `tun_pipe`, commit `bf90fcd141996c7f6ca10f74ebebf1160f8db5fc` ("Add pipe to external program device"), based on OpenVPN `2.6_git`.
- License, as stated in its `COPYING` file: OpenVPN is distributed under the GNU General Public License version 2, with a special exception permitting linking with the OpenSSL library (or modified versions of OpenSSL under the same license) and distributing the linked combination. The full GPLv2 text ships in the tree as `COPYRIGHT.GPL`. The file also notes that the distribution contains multiple components under different licenses and that "OpenVPN" is a trademark of OpenVPN Inc. Copyright (C) 2002-2022 OpenVPN Inc.
- Consequence: the patched client binary built by `build.sh` is GPLv2 licensed. If you redistribute that binary, the GPLv2 terms apply to it. The MIT license in this repo covers only this repo's own scripts and docs.

## tunsocks (the userspace TCP/IP stack)

- Project: russdill/tunsocks, a userspace TCP/IP implementation that terminates connections from raw packets.
- Repository: https://github.com/russdill/tunsocks
- Pinned: `master`, commit `4e4ff8682053412145930b8daf2c55d357cf1e44`, including its git submodules:
  - lwip at `832490eec8ca35bad435fec104512cfbdaf994bf`
  - lwip-libevent at `775be669e08c84eec998b65ce94a3adcf041f8c4`
  - lwip-nat at `e724975569f04c2ea611f3ce5d8d31050c822478`
  - lwip-udhcpd at `f85de3a623dafc02bfe3aa963d21c5a4c8bbb251`
  - eth_udp at `ec1c7e04f40d88b92c335e620d9a735c220b4b44`
- License, as stated in tunsocks' `README.md`: "tunsocks is compiled into and licensed under the same license as lwIP. For a copy of the license, see lwip/COPYING." That file, `lwip/COPYING`, is a BSD-style 3-clause license: Copyright (c) 2001, 2002 Swedish Institute of Computer Science, author Adam Dunkels. Redistribution in source and binary form is permitted with retention of the copyright notice and disclaimer; the author's name may not be used to endorse derived products without prior written permission; the software is provided "as is" without warranty.
- The other submodule trees carried no separate COPYING or LICENSE file at their top level in the pinned clones; they are part of the tunsocks build and are used under the same arrangement as upstream ships them.

## go-openvpn (considered, not used, not fetched by build.sh)

- Project: n0madic/go-openvpn, a pure Go OpenVPN client library with an openvpn2socks SOCKS bridge.
- Repository: https://github.com/n0madic/go-openvpn
- Evaluated at HEAD `383af88` during the engagement (see `docs/meow-writeup.md`, Alternatives). Licensed AGPL-3.0-or-later per its README. It is not a dependency of this repo; it is named here only because the writeup discusses it.

## This repo's own license

Scripts and documentation original to this repo are MIT licensed, see `LICENSE`. That license does not extend to, or change the terms of, any upstream component.
